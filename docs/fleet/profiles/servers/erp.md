# erp — server profile

**Stamp:** profile v1 · 2026-10-19 · sources: [registry.md](../../registry.md) (10-19), [hosts/erp-2026-10-19.md](../../hosts/erp-2026-10-19.md) (survey 2026-10-19 06:26–06:32 WIB), [erp-sysadmin-reports](../../../../erp-sysadmin-reports/README.md) README + sessions 1–3, grobiz-app-reports 001 / 050 / 051 / 052 (erp-side steps), backup snapshot (erp coverage), CLAUDE.md, memory `project_grobiz_hrms_rollout_pending`, `feedback_deploy_main_pin_sha`, `reference_ops_guard_hooks`.
**Rule:** the live snapshot wins over older reports. Drift is listed in its own section below.

## Role

Single Frappe bench (`dns_multitenant`) serving **ERPNext v16 for grobiz**: base site `erp.gro.biz.id` + one site per grobiz tenant (`<hash>.erp.gro.biz.id`) + pre-built `pool-*` sites. No public ingress except SSH. Traffic arrives from `proxy` (`10.0.0.2`) over HTTPS with `proxy_ssl_verify off`. MariaDB is **remote** (`db` `10.0.0.1:3306`; 52 `_<16hex>` site DBs).
**Depends on erp:** grobiz (API on `app` calls `ERPNEXT_URL` and SSHes in as `frappe` to provision sites). Nothing else. **erp depends on:** db (MariaDB), proxy (ingress), backup (off-host copies), monitor (Netdata parent, OpenObserve stream `erp`).

| Item | Value (10-19) |
|---|---|
| IPs / OS | `217.15.166.117` / `10.0.0.6`, Ubuntu 24.04.4, 6 vCPU, 11 GiB RAM, 2 GiB swap (0 used), `/` 193G at 8% |
| Clock | **Europe/Berlin (CEST, WIB − 5 h)**. From **2026-10-25** CET, WIB − 6 h |
| Stack | frappe 16.9.0 (`e5b04e0`), erpnext 16.6.1 (`9a0b54c`), hrms 16.4.1 (**detached HEAD `aa42d57`**), bench at `/home/frappe/frappe-bench` |
| Sites | 52 = 1 base + 48 tenant + 3 `pool-*` (`sites/` 449M) |
| Bench-wide config | `server_script_enabled 1` ([s003](../../../../erp-sysadmin-reports/session-003-2026-09-22.md)), gunicorn `-w 20 -t 300`, 2 short + 2 long workers, `db_host 10.0.0.1` |

## Access

| User | How | Owns / used for |
|---|---|---|
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp` (key only, `PermitRootLogin prohibit-password`, [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #6) | system, supervisor, nginx, UFW, cron, certbot, fluent-bit |
| `frappe` (uid 1000) | `sudo -u frappe bench …` from root; app→erp key `grobiz_erp_provision` in its `authorized_keys` ([grobiz s001](../../../../grobiz-app-reports/session-001-2026-06-05.md)) | the bench and every site; grobiz runs `ssh frappe@10.0.0.6 "bench …"` via the `/usr/local/sbin/bench` cd-shim |
| `devops` (uid 1001) | NOPASSWD sudo, created in [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #6 | fallback login only. **Not in the registry** (see Drift) |
| backup host | ed25519 `backup-pull@backup` ([s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #10) | triggers `bench backup` then rsyncs |

- **fail2ban** sshd jail ([s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #2): `maxretry 5`, `findtime 10m`, `bantime 1h`, `ignoreip` loopback + `10.0.0.0/22`. It's milder than proxy's 24 h, but a bare `ssh erp` still logs in as local user `dedi` and counts as failures. Always name `root@`. The 10-19 snapshot did not check fail2ban.
- UFW: `22/tcp` from anywhere; 80/443 and everything else from `10.0.0.0/22` only; default deny. Direct `https://217.15.166.117` times out by design.
- The ERPNext `Administrator` per-site password is revealed from the grobiz admin dashboard. Never copy it into reports.

## Services

| Kind | Unit / program | Notes |
|---|---|---|
| supervisor (`/etc/supervisor/conf.d/frappe-bench.conf`) | redis-cache `127.0.0.1:13000`, redis-queue `127.0.0.1:11000`, frappe-web (gunicorn `127.0.0.1:8000`), node-socketio **`*:9000`**, schedule, short-worker-0/1, long-worker-0/1 | 9 programs RUNNING 10-19, uptime 2d 18h (bench restarted ~10-16) |
| systemd | nginx (`server_name *.gro.biz.id *.erp.gro.biz.id`), supervisor, netdata (`127.0.0.1:19999`, streams to monitor), fluent-bit (8 bench logs → `10.0.0.3:5080` stream `erp`, [s002](../../../../erp-sysadmin-reports/session-002-2026-05-24.md)), fail2ban, ufw, unattended-upgrades | MariaDB/mysql units inactive: the DB is remote |
| docker | none | |

| Schedule | Server-local | **WIB** (now → after 10-25) | What |
|---|---|---|---|
| `/etc/cron.d/erpnext-backup` | `30 2 * * *` CEST | **07:30 → 08:30** | `bench --site erp.gro.biz.id backup --with-files` as `frappe`, base site only, `backup_limit 7` → `logs/backup.cron.log` |
| backup host `grobiz-sites.sh` | — | 00:00 / 06:00 / 12:00 / 18:00 (~28 min each) | `bench backup --with-files` per tenant site over SSH, then pull; **excludes `pool-*` by design** |
| backup host `erp-bench.sh` | — | 18:00 daily | base site, tier-2 7-day retention |
| frappe scheduler | continuous | — | ~1,500 jobs/h across 45+ HRMS sites (memory) |
| `/etc/cron.d/certbot`, `e2scrub_all`, `sysstat`, `staticroute` (@reboot route fix) | server-local | shifts 1 h vs WIB on 10-25 | no root or frappe user crontab |

## Change procedures

| Change kind | Done in | Safe pattern |
|---|---|---|
| Bench-wide config (`common_site_config.json`) | [s003](../../../../erp-sysadmin-reports/session-003-2026-09-22.md) (server scripts) | `sudo -u frappe bench set-config -g <key> <v>` (bench-wide only: `safe_exec` reads common config, never per-site). Then `sudo -u frappe bench restart`, which blips **all sites ~10 s**. Verify on base + one tenant via `bench --site … console`. Record the rollback command (`set-config -g <key> 0`). |
| Supervisor / gunicorn | [grobiz s050](../../../../grobiz-app-reports/session-050-2026-10-09.md) P16 | **Never run `bench setup supervisor`**: the live `-t 300` would be regenerated as `-t 120`. Edit the conf by hand, back it up first, then `supervisorctl reread && update`. |
| Install an app on sites (HRMS) | [grobiz s051](../../../../grobiz-app-reports/session-051-2026-10-09.md), [s052](../../../../grobiz-app-reports/session-052-2026-10-10.md) | Run a fresh `bench --site all backup` (~28 min). Rehearse on a prod-copy stack. Drive it from app (`pnpm tenant:install-hrms`): dry run → one site → `--max-sites 5` batches → closing dry run. Success = `reached` = site count, not `exit=0`. The `--max-sites` default of 10 makes a fleet "real run" a no-op. Evidence goes to `/root/window0-*`. |
| Site provisioning (grobiz signup) | [grobiz s001](../../../../grobiz-app-reports/session-001-2026-06-05.md) | `bench new-site` runs over `ssh frappe@` (it needs the cd-shim: non-interactive bench fails from `$HOME`). MariaDB `root@10.0.0.6` must exist on db. New sites inherit `common_site_config`. Pool sites are claimed, then the pool is refilled. |
| UFW / sshd / fail2ban hardening | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #2, #5, #6 | Pre-check proxy reaches erp on `10.0.0.2`. Add allow rules before `ufw enable`. Test a fresh key login (root + devops) **before** reloading sshd. Back up to `sshd_config.bak.<date>`. Verify externally: 22 open, 80/443/9000/19999 closed. |
| Package upgrade + reboot | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #9 | `apt upgrade` restarts supervisor/frappe by itself, so do it in a quiet hour (merchant peak is **06:00 WIB**, [grobiz s050](../../../../grobiz-app-reports/session-050-2026-10-09.md) P6). Then `full-upgrade` + reboot (~90 s outage). Afterwards check 9 programs RUNNING, UFW, fail2ban, swap, netdata on loopback, `erp.gro.biz.id` 200 through proxy. |
| Log shipping | [s002](../../../../erp-sysadmin-reports/session-002-2026-05-24.md) | Back up `fluent-bit.conf` to `.bak.<date>`. The Lua filter sets `log_name`/`log_type`. Zero records on a quiet bench is normal. |
| Cert (erp's own `gro.biz.id`) | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #7 | It is independent of proxy's lineage (DNS-01, its own certbot). `certbot renew --dry-run` is read-mostly. Proxy does not verify the origin cert, so a stale erp cert fails silently. |
| nginx on erp | (bench-generated) | `nginx -t` before `systemctl reload nginx`. Back up to `/root/nginx-backups/`, never into `sites-enabled/`. Don't regenerate with `bench setup nginx` without diffing against live first. |

## Health checks (read-only)

```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'supervisorctl status 2>/dev/null; ufw status; fail2ban-client status sshd; systemctl is-active nginx netdata fluent-bit supervisor; free -h; df -h /'
ssh … root@erp 'cd /home/frappe/frappe-bench && sudo -u frappe bench version; ls sites | grep -c "erp.gro.biz.id$"; ls -d sites/pool-*; tail -3 logs/backup.cron.log'
ssh … root@erp 'curl -sk -o /dev/null -w "%{http_code}\n" -H "Host: erp.gro.biz.id" https://127.0.0.1/api/method/ping'
ssh … root@erp 'cd /home/frappe/frappe-bench && for s in sites/*.erp.gro.biz.id; do n=$(basename $s); echo "$n $(sudo -u frappe bench --site $n scheduler status 2>/dev/null | tail -1)"; done'   # slow: ~52 bench calls
```

## Known noise

- `supervisorctl` prints a `pkg_resources` deprecation warning (10-19 snapshot). Harmless.
- `cloud-init.service` is a failed unit, a Contabo image quirk that pre-existed ([s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) carry #4).
- Fluent Bit ships few or zero records because the bench is quiet ([s002](../../../../erp-sysadmin-reports/session-002-2026-05-24.md)).
- Socket.IO on `*:9000` is by design. Frappe's `server.listen(port)` has no host argument, so UFW covers it ([s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #4).
- Holiday List 403s in the HRMS baseline logs at `a3638ba58` are expected until `HR Manager` arrives ([grobiz s051](../../../../grobiz-app-reports/session-051-2026-10-09.md)).
- Log timestamps are CEST (WIB − 5 h) until 10-25, then CET.

## Open follow-ups

| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | `hrms` is on a **detached HEAD `aa42d57`**, not `version-16`. A `bench update` / `switch-to-branch` would behave unpredictably. Decide whether to pin it to a tag or branch before any bench update. | new-on-10-19 | snapshot; [grobiz s051](../../../../grobiz-app-reports/session-051-2026-10-09.md) | high |
| 2 | Tenant sites went from 45 to **48** since the HRMS rollout. Verify the 3 new tenants have `hrms`, scheduler `enabled` and `Asia/Jakarta` (pool sites carry HRMS, but this hasn't been checked). | new-on-10-19 | snapshot vs memory / [grobiz s052](../../../../grobiz-app-reports/session-052-2026-10-10.md) | high |
| 3 | **DST 2026-10-25:** the local backup moves 07:30 → 08:30 WIB and log offsets become −6 h. Update runbooks and any cross-host time math. | new-on-10-19 | snapshot; registry §10 | med |
| 4 | erp's own `gro.biz.id` cert: expiry and renewal weren't surveyed on 10-19, and it isn't known whether erp nginx reloads after a renewal (proxy has no deploy hook). | carried + gap | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) M1/#7 | med |
| 5 | fail2ban and fluent-bit weren't covered by the 10-19 snapshot. Re-verify both are active. | new-on-10-19 (gap) | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md), [s002](../../../../erp-sysadmin-reports/session-002-2026-05-24.md) | med |
| 6 | Supervisor drift: live `-t 300` vs generated `-t 120`. Keep the "never `bench setup supervisor`" rule, or fold `-t 300` into bench config. | carried | [grobiz s050](../../../../grobiz-app-reports/session-050-2026-10-09.md) P16 | med |
| 7 | Socket.IO `*:9000` relies only on UFW. If UFW is ever disabled it becomes public. | carried | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) H1 | low |
| 8 | Server Scripts are on bench-wide. Guardrail: never add `Script Manager` to grobiz `ERPNEXT_ROLE_MAP`. | carried | [s003](../../../../erp-sysadmin-reports/session-003-2026-09-22.md) | low |
| 9 | The `grobiz-sites.sh` 06:00 WIB run overlaps the merchant daily peak (06:00). Consider shifting it. | new-on-10-19 | [grobiz s050](../../../../grobiz-app-reports/session-050-2026-10-09.md) P6 + snapshot | low |
| 10 | `devops` user exists but the registry says root-only. Reconcile, or remove the account if unused. | new-on-10-19 | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #6 | low |
| 11 | `cloud-init.service` failed unit; rsyslog `/var/log/ufw.log` permission warning. Re-check or accept. | carried | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) carry #4–5 | low |
| 12 | Cross-host: `/opt/backup/config.sh` on backup holds plaintext credentials, and the copies are unencrypted (owned by the backup profile). | carried | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) carry #3 | low |
| — | Closed: cluster IP map (now in CLAUDE.md + registry §1); first backup run verified (backup host 10-19 shows fresh erp dumps). | done | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #11, carry #6 | — |

The README has no "Open follow-ups" section yet. This table is the first consolidated list.

## Drift: reports vs live 10-19

| Report said | Live 10-19 shows | Source |
|---|---|---|
| "all 41 sites" | 52 sites (48 tenant + base + 3 pool) | [s003](../../../../erp-sysadmin-reports/session-003-2026-09-22.md) |
| "49 site DBs: 45 tenants, base, 3 pool" | 48 tenants. Registry also says 52 MariaDB site DBs | memory `project_grobiz_hrms_rollout_pending` |
| `erp-bench` pull "tonight at 01:00 WIB" | daily 18:00 WIB (inside `backup.sh`), plus `grobiz-sites.sh` every 6 h | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #10 |
| HRMS rollout "done" (branch not stated) | `hrms` on a detached HEAD `aa42d57` | memory; [grobiz s051](../../../../grobiz-app-reports/session-051-2026-10-09.md) |
| `devops` sudo user created | registry lists `root` (+ bench user `frappe`) only | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #6 vs registry §1 |
| fail2ban active (1 h ban) | not checked by the survey: unverified, not contradicted | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) #2 |
| README: "Will be consumed by the future grobiz app" | grobiz has been live since 2026-06 with 48 tenants. The README intro is stale | README |
| Disk 8.0G used (05-17) | 15G used (8%) | [s001](../../../../erp-sysadmin-reports/session-001-2026-05-17.md) |

These match: UFW rules, netdata on loopback, 2 GiB swap, gunicorn `-w 20 -t 300`, 2+2 workers, the frappe/erpnext versions, base-site cron 02:30 local.

## Verify live

```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'timedatectl | grep "Time zone"; hostnamectl | grep Operating; uptime'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'ss -tlnpH; ufw status verbose; fail2ban-client status sshd'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'cd /home/frappe/frappe-bench && sudo -u frappe bench version && for a in frappe erpnext hrms; do echo "$a $(git -C apps/$a rev-parse --abbrev-ref HEAD) $(git -C apps/$a rev-parse --short HEAD)"; done'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'ls /home/frappe/frappe-bench/sites | grep -E "erp.gro.biz.id$|^pool-" | wc -l; grep -o "\"server_script_enabled\": *[0-9]" /home/frappe/frappe-bench/sites/common_site_config.json'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'cat /etc/cron.d/erpnext-backup; grep -- "-t " /etc/supervisor/conf.d/frappe-bench.conf | head -1; certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry"'
```
