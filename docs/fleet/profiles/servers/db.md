# db — server profile

**Stamp:** profile v1 · 2026-10-19 · sources: [registry.md](../../registry.md) (10-19 §1, §4, §5), [hosts/db-2026-10-19.md](../../hosts/db-2026-10-19.md) (survey 2026-10-19 06:26 WIB), [db-sysadmin-reports](../../../../db-sysadmin-reports/README.md) README + sessions 001–004, CLAUDE.md, memory (`reference_ops_guard_hooks`, `feedback_psql_on_app_never_echo_db_url`, `feedback_never_delete_real_data`); cross-refs [backup snapshot](../../hosts/backup-2026-10-19.md), meetgrab s007, ytgrab s020/s036, miaw-route s004, grobiz s008/s037, rekrutme s002, pahala s001.

## Role
Stateful core of the cluster: `db.biji.uk`, public 109.123.233.215, private **10.0.0.1** (the LAN gateway for 10.0.0.0/22), Ubuntu 22.04.5, 12 vCPU / 47 GiB / 490 G disk (43 % used), uptime 396 d. It runs PG 16.9, Redis 8.6.1, MariaDB 10.6.22, Mongo 8.0.10 and ClickHouse 26.1.3, plus the ytgrab-api secondary on root PM2.
**Dependents:** every PG app on `app` (wagrab, asiaweek, eventopia, feyfa, grobiz, seenow, hoteru×4, rekrutme, pahala, avilia, miaw-route, duitkas×2, pasarbesar×3, meetgrab), GlitchTip + OpenPanel on monitor (PG, Redis db2/db3, ClickHouse), all 52 ERPNext sites on erp (MariaDB), quranchat (Mongo), ytgrab (`ytgrab_prod`, Redis db0, also from numa). The `backup` host pulls PG and Mongo dumps from here.

## Access
| User | How | Owns |
|---|---|---|
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@db` (direct; the "monitor jump host" in [s002](../../../../db-sysadmin-reports/session-002-2026-05-24.md) is obsolete) | everything; PM2 `ytgrab-api` + `bgutil-pot` (`/root/ytgrab`, `/root/bgutil-pot`); `/root/.my.cnf` (MariaDB root); `/root/.cloudflare.ini` (DNS-01 token) |
| `postgres` | `sudo -u postgres psql` (`local all postgres trust`) | PG superuser, the only one; owns `ytgrab_prod`, `verify_wagrab_484379` |
| `mongo-express` | system user, no shell | `/opt/mongo-express` (moved off root in [s001](../../../../db-sysadmin-reports/session-001-2026-05-05.md)) |
| app roles | from app/monitor/backup/numa over 10.0.0.1:5432 | one owner role per DB (registry §5); `backup_reader` = `pg_read_all_data` + BYPASSRLS |

- **Ban risk: none, which is also the risk.** fail2ban is not installed, `PermitRootLogin yes` and **`PasswordAuthentication yes`**, and port 22 is open to Anywhere (v4+v6). It is the only admin surface in the fleet that is internet-exposed with no allowlist (snapshot anomaly 1).
- psql from `app` with a URL taken from `.env`: double-quote the variable and pipe through a redaction sed, because a quoting slip printed a prod password on 2026-10-18 (memory `feedback_psql_on_app_never_echo_db_url`). The `ops-guard` hook blocks the unquoted form.
- Admin UIs go through Cloudflare → Apache: `https://db.biji.uk/{phpmyadmin,pgadmin4,mongo}`. UFW allows 80/443 from the CF ranges only ([s001](../../../../db-sysadmin-reports/session-001-2026-05-05.md)).

## Services
**Clock:** OS Asia/Jakarta (WIB). **PG session TZ is Asia/Singapore (+08)**, MariaDB `time_zone=SYSTEM` (WIB). The PG postmaster was last started 2026-06-20 ([s003](../../../../db-sysadmin-reports/session-003-2026-06-20.md)).

| Kind | Unit / process | Bind | UFW allow-from |
|---|---|---|---|
| systemd | `postgresql@16-main` (drop-in `LimitNOFILE=65536`, s003) | localhost,10.0.0.1:5432 | 10.0.0.3/.4/.5/.7 |
| systemd | `redis-server` (no auth, `protected-mode no`, RDB only, `noeviction`, `maxmemory 0`) | 127.0.0.1,10.0.0.1:6379 | 10.0.0.3/.5/.7 |
| systemd | `mariadb` (52 site DBs `_<16hex>`, ≈2.9 GB) | 10.0.0.1:3306 | 10.0.0.6 only |
| systemd | `mongod` (no `security:` section, so no auth) | 127.0.0.1,10.0.0.1:27017 | 10.0.0.4/.5 |
| systemd | `clickhouse-server` | 127.0.0.1,10.0.0.1:8123/9000 (+9004/9005/9009) | 10.0.0.3 on 8123/9000 |
| systemd | `apache2` (db.biji.uk admin UIs), `mongo-express` (127.0.0.1:8081) | 0.0.0.0:80/443 | CF ranges |
| systemd | `netdata` (:19999; health override `postgres-noise.conf`, s004), `fluent-bit` → OpenObserve stream `db` (s002) | 0.0.0.0:19999 | 10.0.0.0/22, deny rest |
| PM2 (root) | `ytgrab-api` (:7009, secondary, weight 1, `nice -n 10`), `bgutil-pot` (:4416) | 10.0.0.1:7009 / **`*:4416`** | 7009 from proxy; 4416 default-deny |
| disabled | PgBouncer (unconfigured, s001); Docker is not installed | — | — |

| Schedule (WIB) | What | Where defined |
|---|---|---|
| 18:00 daily | backup Tier 1/2/3 PG + wagrab + quranchat Mongo pull | backup root crontab |
| 00/06/12/18:00 | grobiz PG pull | backup root crontab |
| Tue 21:00 | `verify.sh` restore test (it is what leaves `verify_*` DBs behind) | backup root crontab |
| 2×/day | certbot renew of `db.biji.uk` (DNS-01, `/root/.cloudflare.ini`) | assumed apt timer; **not surveyed 10-19** |
| — | Local cron/timers on db were **not enumerated** in the 10-19 survey. Run the verify command below before relying on this table. | — |

## Change procedures
| Change | Done in | Safe pattern |
|---|---|---|
| New app role + DB | rekrutme s002, pahala s001, meetgrab s007 | • `CREATE ROLE <app> LOGIN` plus `CREATE DATABASE <app> OWNER <app>`, with the password sent **over stdin**, never in argv or the transcript • owner gets no superuser, CREATEDB or CREATEROLE (seenow is the documented exception) • `CREATE` on the DB only if the app makes schemas at runtime (rekrutme: drizzle, pgboss) • untrusted extensions created as `postgres` • confirm `backup_reader` can connect and SELECT; tier-2 auto-discovery picks the DB up the next 18:00 WIB • add the row to registry §5 |
| Redis db allocation | seenow s003 (db7), hoteru (db8–11) | • next free is **db 12** • check `INFO keyspace` **and** `CLIENT LIST` (db=N) • prefix the keys • **never FLUSHDB/FLUSHALL**: db0 is shared; delete with `--scan --pattern` scoped to exact keys (ytgrab [s036](../../../../ytgrab-app-reports/session-036-2026-09-02.md): 14 keys removed, 30k untouched) |
| Timestamp migrations | miaw-route s004, grobiz s008 | • `now()` writes in **Asia/Singapore** • use `AT TIME ZONE 'Asia/Singapore'` explicitly when converting naive columns • check `SHOW timezone` first |
| UFW change | s001 (CF 80/443, netdata) | • `ufw status numbered` before and after • allow from the specific 10.0.0.x, never Anywhere, for DB ports • the CF range refresh loop is in s001; prune ranges CF has dropped by hand • keep 22 open until an SSH allowlist is agreed (no console fallback is recorded) |
| PG config / systemd limit | s001 (`listen_addresses`), s003 (NOFILE) | • drop-in under `/etc/systemd/system/postgresql@16-main.service.d/` → `daemon-reload` • **a restart is fleet-wide**: every app's connection drops for 1–2 s, so get approval and do it off-peak • verify with `/proc/<pid>/limits` and `select 1`, and count reconnected backends • `pg_hba` edits need only `pg_reload_conf()`, no restart |
| Netdata alarm tuning | [s004](../../../../db-sysadmin-reports/session-004-2026-09-20.md) | • override a stock template by copying the **full** definition into `/etc/netdata/health.d/*.conf` • `netdatacli reload-health` • revert by deleting the file |
| Log shipping | [s002](../../../../db-sysadmin-reports/session-002-2026-05-24.md) | • back up `fluent-bit.conf` with a `.bak.<date>` suffix • Fluent Bit 5.x on 22.04 rejects `multiline.parser`, so leave it out • verify the stream `db` count in OpenObserve |
| MariaDB credentials | s001 | • rotate in lockstep with `phpmyadmin` `config-db.php` + dbconfig-common • keep `/root/.my.cnf` at mode 600 • ERPNext site users belong to erp/bench, not here |
| Package upgrade | **never done** in any db session | • 257 packages pending, uptime 396 d • schedule a window: PG/Redis/MariaDB restarts hit every app • snapshot or confirm last night's backup first |

## Health checks (read-only)
- `systemctl is-active postgresql@16-main redis-server mariadb mongod clickhouse-server apache2 netdata fluent-bit`
- `sudo -u postgres psql -XAt -c "select count(*) from pg_stat_activity where backend_type='client backend'"` (~118 of 200 on 10-19)
- `redis-cli INFO keyspace; redis-cli INFO memory | grep used_memory_human`
- `df -h /; du -sh /var/lib/clickhouse /var/lib/postgresql`
- `clickhouse-client -q "select database, formatReadableSize(sum(bytes_on_disk)) from system.parts group by 1"`
- `pm2 ls` (root) · `ufw status numbered` · `free -h`

## Known noise
- Netdata `postgres_db_transactions_rollback_ratio` and `postgres_acquired_locks_utilization` are routed to `silent` ([s004](../../../../db-sysadmin-reports/session-004-2026-09-20.md)). The signal is app-side aborted transactions and lives only in the dashboard and ledger. `postgres_db_cache_io_ratio` still sends.
- The PG fd-utilisation alert near 100 % was a soft-NOFILE artefact, fixed in s003. If it comes back, check the drop-in.
- ~118 PG backends and 111 Redis clients are normal. DBs with 0 connections at survey time (pahala, duitkas, pasarbesar, meetgrab, ytgrab_prod) connect on demand and are not dead by default.
- Swap is 1.8 / 4 GiB used with 24 GiB RAM available. That is long-uptime residue, not pressure.

## Open follow-ups
| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | SSH: password auth on, root login, no fail2ban, 22 open to Anywhere. Disable password auth and/or add fail2ban or an allowlist | new-on-10-19 | snapshot anomaly 1 | **high** |
| 2 | ClickHouse `system` logs at **71.5 GiB** (trace_log 29.9, text_log 23.8) with no TTL, against 243 MiB of openpanel data. Add TTLs or `log` config limits, then truncate | new-on-10-19 | snapshot anomaly 5 | **high** |
| 3 | 257 upgradable packages, 396 d uptime, no upgrade ever recorded | new-on-10-19 | snapshot anomaly 19 | high |
| 4 | Redis no auth + Mongo no auth + ClickHouse `default@::/0` (password not checked). Only UFW protects them | new-on-10-19 | anomalies 2–4 | med |
| 5 | `pg_hba`: delete the `109.123.233.215/21 md5` line, collapse the 4 redundant `10.0.0.x/22` lines, review `local postgres trust` | carried | [s001](../../../../db-sysadmin-reports/session-001-2026-05-05.md) / README | med |
| 6 | 6 stale MariaDB admin grants (`root@10.0.0.2/.3/.4/backup`, `erpnext@10.0.0.3`, `maria@10.0.0.3`). Still present 10-19 | carried | s001 / README | med |
| 7 | Drop the leftover `verify_wagrab_484379` (130 MB) **and** fix backup's `verify.sh` so it cleans up after itself | carried | s003 notes, backup snapshot | low |
| 8 | Monitor `wagrab` growth: 89 GB (05-05) → 90 GB (10-19), now flat | carried | s001 / README | low |
| 9 | Redis db7 (seenow prod) has 0 keys and 0 clients. Check seenow's `REDIS_URL` on app | new-on-10-19 | anomaly 8 | med |
| 10 | `bgutil-pot` binds `*:4416`. Rebind to 127.0.0.1 (ytgrab docs say it already is) | new-on-10-19 | anomaly 18 | low |
| 11 | `ytgrab_prod` is owned by and accessed as the `postgres` superuser (ytgrab [s020](../../../../ytgrab-app-reports/session-020-2026-06-28.md)). Create a `ytgrab` owner role | new-on-10-19 | anomaly 11 | med |
| 12 | PUBLIC CONNECT on every DB. `REVOKE CONNECT … FROM PUBLIC` per DB, keeping the owner and `backup_reader` grants | new-on-10-19 | anomaly 13 | low |
| 13 | Shared Redis db0 (pasarbesar + ytgrab incl. numa + duitkas baznas). Consider splitting into free dbs 12+ | new-on-10-19 | anomaly 7 | low |
| 14 | ClickHouse, MariaDB and Redis are **not backed up** by backup's jobs (MariaDB is covered only through erp bench backups) | new-on-10-19 | backup snapshot | med |
| 15 | `db.biji.uk` cert: s001 left expiry 2026-08-03 with "auto-renew". Renewal was not verified on 10-19 | carried | s001 | low |
| 16 | The s001 report body contains the **old** (since-rotated) MariaDB root password in plain text. Redact it from the doc | new-on-10-19 | s001 §Actions 6 | low |

## Drift: reports vs live 10-19 (live wins)
| Report said | Live 10-19 shows | Source |
|---|---|---|
| "db has no public SSH", reached via the monitor jump host | 22 open to Anywhere, password auth on, direct `root@db` works | db s002 vs snapshot |
| UFW 5432 from monitor/backup/app; 6379 from monitor/app | **numa 10.0.0.7** also allowed on 5432 and 6379 (never recorded in a db session) | s001 vs snapshot |
| MariaDB has 1 ERPNext site DB | 52 site DBs, 51 site users `@'%'` | s001 vs snapshot |
| PG DB list: `miawflow` (no meetgrab) | `miawflow` gone (split into `miawflow_baznas`/`_lpekin`); `meetgrab` DB exists (created in meetgrab s007, 2026-06-28). **CLAUDE.md's "meetgrab: No database" is stale** | s001, CLAUDE.md vs snapshot |
| bgutil-pot on `127.0.0.1:4416` | listens on `*:4416` | ytgrab README vs snapshot |
| Redis 3.6 MB, dbs 0/2/3 only | 309 MB, dbs 0–11 in use | s001 vs snapshot |
| glitchtip 407 MB | 2.6 GB | s001 vs snapshot |
| "Monitor `pg_hba` /21 line, delete for hygiene" | still present | README vs snapshot |

## Verify live
```bash
S="ssh -o BatchMode=yes -o ConnectTimeout=15 root@db"
$S 'timedatectl | grep "Time zone"; uptime; df -h /; apt list --upgradable 2>/dev/null | wc -l'
$S 'sshd -T | grep -E "^(permitrootlogin|passwordauthentication)"; systemctl is-active fail2ban; ufw status numbered'
$S "sudo -u postgres psql -XAt -c 'show timezone' -c 'select datname, pg_get_userbyid(datdba), pg_size_pretty(pg_database_size(datname)) from pg_database order by 1'"
$S 'redis-cli INFO keyspace; redis-cli CLIENT LIST | grep -o "db=[0-9]*" | sort | uniq -c'
$S 'clickhouse-client -q "select table, formatReadableSize(sum(bytes_on_disk)) from system.parts where database='"'"'system'"'"' group by 1 order by sum(bytes_on_disk) desc"'
$S 'pm2 ls; ss -tlnpH | grep -E ":(4416|7009)"; crontab -l; ls /etc/cron.d; systemctl list-timers --no-pager'
$S 'certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry"'
```
