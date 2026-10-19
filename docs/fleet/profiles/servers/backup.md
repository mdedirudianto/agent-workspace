# backup — server profile

**Stamp:** profile v1 · 2026-10-19 · sources: [registry.md](../../registry.md) (10-19), [hosts/backup-2026-10-19.md](../../hosts/backup-2026-10-19.md), [backup-sysadmin-reports](../../../../backup-sysadmin-reports/README.md) README + sessions 1–5, grobiz-app [s006](../../../../grobiz-app-reports/session-006-2026-06-07.md) / [s034](../../../../grobiz-app-reports/session-034-2026-08-28.md), CLAUDE.md. Live snapshot wins where they disagree (see Drift).

## Role

Pull-based backup target: `194.233.81.93` / `10.0.0.4`, Ubuntu 22.04.5, 2 vCPU / 2.9 GiB / 776 G disk (40 % used 10-19). Cron in `/opt/backup` pulls into `/root/backups`. Copies are **local-only and unencrypted**. Nothing serves traffic from here.

| Pulls from | What | Job |
|---|---|---|
| db `10.0.0.1` PG 16 | every non-template DB: Tier 1 `wagrab`, Tier 2 auto-discovered (asiaweek, avilia, eventopia, feyfa, hoteru×4, meetgrab, miaw_route, miawflow_baznas/lpekin, pahala, pasarbesar×3, rekrutme, seenow, ytgrab_prod), Tier 3 `glitchtip`/`openpanel`, GFS `grobiz` | `wagrab-pg`, `tier2-pg`, `tier3-pg`, `grobiz-pg` |
| db Mongo 8 | `quranchat` only (Mongo DB list never enumerated) | `quranchat-mongo` |
| erp `10.0.0.6` | `erp.gro.biz.id` bench `--with-files`; 48 grobiz tenant sites (`<hash>.erp.gro.biz.id`). `pool-*` is skipped by design | `erp-bench`, `grobiz-sites` |
| app `10.0.0.5` (devops) | grobiz `.env` (appconfig) and the WA gateway session dir (Baileys creds, which can't be re-issued) | `grobiz-appconfig`, `grobiz-wasessions` |
| **Not backed up** | Redis (incl. eventopia db6, which **holds Redis-only state**), ClickHouse, MariaDB as such (the ERPNext DBs are covered through bench), Vaultwarden/monitor volumes | — |

Depends on it: every app with a Postgres DB on db, grobiz (PG + tenants + creds), ERPNext, quranchat. Alerts go to Telegram through `notify.sh`, and Fluent Bit ships them to the OpenObserve `backup` stream.

## Access

| Direction | User / key | How | Notes |
|---|---|---|---|
| Mac → backup | `root`, key-only | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup` | `00-hardening.conf` sets no password and `MaxAuthTries 3` ([s001](../../../../backup-sysadmin-reports/session-001-2026-05-17.md)). 4 authorized keys as of s001 (the 2016 `rsa-key-20160704` was pruned) |
| fallback | via monitor | `ssh -J root@217.15.162.56 root@10.0.0.4` | used in [s002](../../../../backup-sysadmin-reports/session-002-2026-05-25.md) when public :22 refused (probably a fail2ban ban) |
| fail2ban | sshd jail, `aggressive` | maxretry 5 / findtime 10m / **bantime 1h**, ignoreip `10.0.0.0/22` | Softer than proxy's 24 h. A bare `ssh backup` connects as local user `dedi` and burns attempts |
| backup → erp | `/root/.ssh/id_ed25519_pull` (`backup-pull@backup`) → `root@erp` | runs `sudo -u frappe bench … backup`, then rsync | s001 / [s004](../../../../backup-sysadmin-reports/session-004-2026-08-03.md) |
| backup → app | same key → `devops@app`, `from="10.0.0.4"` + forced `cat ~/grobiz/.env` | appconfig | grobiz s006 |
| backup → app | `id_ed25519_wasessions_pull`, forced-command tar stream | wasessions | grobiz s034 |
| backup → db PG | `backup_reader` (`pg_read_all_data` + BYPASSRLS) for dumps; `postgres` (`PG_ADMIN_USER`) **only** for verify temp-DB create/restore/drop | `config.sh` (mode 600; names only, never print values) | [s003](../../../../backup-sysadmin-reports/session-003-2026-06-20.md). db pg_hba allows `10.0.0.4/22` md5 |
| backup → db Mongo | no auth | `10.0.0.1:27017`, UFW allows from backup and app | db snapshot |

Ownership: everything is root (`/opt/backup` 700, `config.sh` 600, `/root/backups`). UFW allows 22/tcp from anywhere and nothing else.

## Services

Clock: **Asia/Jakarta (WIB)**, so the crontab is already in WIB. erp and app clocks are CEST (WIB −5 h; −6 h after 2026-10-25 DST), but that only affects their own log timestamps, not this schedule.

| Unit / cron (root crontab) | WIB schedule | Notes |
|---|---|---|
| `backup.sh` (T1/T2/T3 PG, wagrab, mongo, erp-bench, inline rotate) | daily **18:00** | wagrab takes about 1 h. Dumps land around 19:09, glitchtip/mongo/erp around 19:14 |
| `backup-grobiz.sh` (grobiz PG, sites, appconfig, wasessions, GFS rotate) | **00:00 / 06:00 / 12:00 / 18:00** | about 30 min per run (10-19 06:00 run ended 06:32) |
| `rotate.sh` | **Sun 20:00** | mostly redundant, since backup.sh rotates inline |
| `verify.sh` | **Tue 21:00** | last run 10-13: 66 PASSED / 0 FAILED. Next is 10-20 |
| `fluent-bit` (systemd) | always on | tails `/var/log/backup.log` and syslog, sends to `10.0.0.3:5080` stream `backup`, 30 d retention (s002) |
| `fail2ban`, `unattended-upgrades` | always on | s001 |
| `netdata` 2.12.1 | **disabled / dead** | so monitor has no metrics or disk alarms for this host |
| containerd / docker | present | 22 G of miaw SIP-lab images. `miaw-sip-lab-asterisk-1` exited on about 10-17. Not documented in any backup session |
| Retention | T1 wagrab 4 d (5 files live), T2 7 d (8 files), T3 3 d (4 files), grobiz GFS 24 h intraday / 7 d daily / 30 d weekly | `config.sh` `GROBIZ_*`, `TIER2_EXCLUDE` |

## Change procedures

| Change | Sessions | Safe pattern |
|---|---|---|
| New app DB on db | [s003](../../../../backup-sysadmin-reports/session-003-2026-06-20.md) | Nothing to edit: Tier 2 auto-discovers it (`datname !~ '^verify_'`, minus `TIER2_EXCLUDE`). After the next 18:00 run, check the `[tier2] Auto-discovered N DB(s)` line. To give a DB its own tier, add it to `TIER2_EXCLUDE` **and** give it its own job and prune block, because the dump and prune lists both read that exclude list |
| Edit a job or rotate/verify script | s003, [s004](../../../../backup-sysadmin-reports/session-004-2026-08-03.md), [s005](../../../../backup-sysadmin-reports/session-005-2026-09-22.md) | `cp x x.bak-YYYYMMDD`, edit, `bash -n`, then run the single job by hand and check `EXIT=0` and the log tail. **Gotcha (s004):** an `ssh` inside `while read … <<< "$LIST"` eats the loop's stdin, so give it `< /dev/null` (`-n`). That bug meant only 1 of 11 sites was ever backed up. Don't edit during a run (18:00–19:20, or :00–:35 of a grobiz hour) |
| New pull source on another host | grobiz s006, s034 | Reuse or create a dedicated key. On the source host, pin it with `from="10.0.0.4"` and a forced `command=` plus no-pty / no-forwarding. Add the job to the right wrapper and to `rotate.sh` and `verify.sh`, then test end to end before the source has real data |
| grobiz site rename or decommission on erp | s005 | `verify.sh` scans every local dir, so a renamed site reads as `no db archive` once its old files age out. Look for the sibling `.erp.` dir before you assume data loss. `rotate.sh` now `rmdir`s **empty** site dirs only. Dirs that still hold old files stay until GFS ages them out (about 30 d) |
| Restore verify | s003, grobiz s006 | `verify.sh <name>`: under 1 GB it does a full restore into a temp DB on db as `PG_ADMIN_USER`, then drops it. ≥ 1 GB gets `--list` only. Mongo gets `--dryRun`. grobiz is non-destructive (`--list` + `gzip -t`). Afterwards check db for leftover `verify_*` DBs |
| Package upgrade / reboot | s001 | Do it only after the daily run finishes (after about 19:20 WIB) and away from the grobiz :00 slots. The 21:00 Tue verify uses db too. Confirm `crontab -l` and `fluent-bit` survive the reboot |
| Credential rotation (PG / monitor DBs / Telegram) | s003, monitor README | Rotate on db, then update `config.sh` **in the same step**, then run one job by hand. Never print `config.sh`; read variable names only |

## Health checks (read-only)

- `tail -40 /var/log/backup.log`, then `grep -nE 'FAIL|ERROR' /var/log/backup.log | tail -20`
- `for d in /root/backups/{pg,mongo,bench}/*/; do echo "$d $(ls -t $d | head -1)"; done` (everything should be under 26 h old; grobiz under 6 h)
- `df -h /`, then `du -sh /root/backups/pg/wagrab /var/tmp /var/lib/containerd`
- `crontab -l`, then `systemctl is-active fluent-bit fail2ban cron`, then `fail2ban-client status sshd`
- `grep -E 'verify.*(PASSED|FAILED)' /var/log/backup.log | tail -3`

## Known noise

- Restoring onto PG16 warns about `SET transaction_timeout`, because the backup host's pg_dump client is newer (s003). Harmless.
- The `pasarbesar` dump is 909 B. The DB is empty, and verify SKIPs DBs with ≤ 4 objects (s001).
- `pool-*` ERPNext sites are excluded by design (reconstructible).
- UFW BLOCK and brute-force sshd lines fill the OpenObserve `backup` stream (s002).
- On monitor, Netdata `streaming_never_connected` is backup, and it is expected while Netdata stays disabled.
- `grobiz-site:… no db archive` right after a tenant rename is usually an orphan dir (s005).

## Open follow-ups

| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | No offsite copy: all 197 G sit on one VPS. Options are rclone to S3/B2, restic or BorgBase | carried | s001 (also grobiz s006) | **high** |
| 2 | No encryption at rest (wagrab is 39 G of plain user data). restic would fix this and #1 together | carried | s001 | **high** |
| 3 | `grobiz-wasessions` pull failed 10-14 12:37, 10-15 18:55 and 10-18 12:32 (each run "Completed with 1 error"). These are the creds with no re-issue path | new-on-10-19 | snapshot; job from grobiz s034 | **high** |
| 4 | Stores with no backup: Redis (eventopia db6 is Redis-only state), ClickHouse, Mongo DBs other than quranchat (never enumerated), monitor's Vaultwarden/Kuma volumes | new-on-10-19 | snapshot + registry §4 | med |
| 5 | Netdata installed but disabled, so there are no disk or host alarms for the backup target | new-on-10-19 | snapshot, monitor snapshot | med |
| 6 | Non-backup workload: `/var/tmp/miaw-*` SIP/audio artifacts take 75 G (09-20 → 09-29), plus 22 G of containerd SIP-lab images. Ask the owner before removing anything | new-on-10-19 | snapshot | med |
| 7 | wagrab is 191 G (97 % of the data, 5 × 39 G). Watch growth against the 469 G free | new-on-10-19 | snapshot | low |
| 8 | Leftover `verify_wagrab_484379` (130 MB) on db. It already existed at s003. Dropping it is a write on db | carried | s003, snapshot | low |
| 9 | Stale dirs: `pg/miawflow` (empty since 06-27), `pjstore` (empty since 2025-03), grobiz orphans `04cb57c2`, `2244bf02` (still hold old files) | new-on-10-19 | snapshot | low |
| 10 | `/var/log/backup.log` (13.7 MB) has no logrotate entry. 14 `*.bak*` script copies sit in `/opt/backup` | new-on-10-19 | snapshot | low |
| 11 | Decide whether to bind SSH to eth1 (10.0.0.4) only | carried | s001 | low |
| 12 | Remove NetworkManager (redundant with networkd). Telegram bot token is cleartext in `config.sh` | carried | s001 | low |

## Drift: reports vs live 10-19

| Report said | Live 10-19 shows | Source |
|---|---|---|
| Cron times given as UTC: backup "18:00 UTC / 01:00 WIB", verify "Tue 21:00 UTC / Wed 04:00 WIB" | The host TZ is WIB, so the crontab means 18:00 WIB daily, Sun 20:00 and Tue 21:00 WIB. s002's own log line already read "06:00 PM WIB" | s001, s002 |
| "Pure backup destination", unused services stripped | containerd and miaw SIP-lab containers, plus 75 G in `/var/tmp`. No backup session records this | s001 |
| CLAUDE.md: Netdata alarms "across all 5 cluster hosts" | Netdata on backup is disabled and has never streamed to monitor | CLAUDE.md, monitor snapshot |
| Retention T1 = 4 d, T3 = 3 d | 5 wagrab dumps, 4 glitchtip/openpanel dumps on disk (an off-by-one keep, or the rotate timing) | s001 |
| README lists 3 grobiz jobs (pg / sites / appconfig) | 4 jobs: `grobiz-wasessions` was added in grobiz s034 and is missing from the backup README | README |
| 37 tenant sites (s005), 11 (s004) | 48 tenant sites backed up, 3 pool sites skipped, 2 orphan dirs | s004, s005 |
| Disk 31 % (s003) | 40 % (307 G used), with 97 G of it non-backup | s003 |
| Public :22 refused, so use ProxyJump through monitor | The 10-19 survey reached root@backup directly. The s002 refusal was most likely a temporary 1 h ban | s002 |

## Verify live

```sh
B='ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup'
$B 'timedatectl | grep "Time zone"; crontab -l | grep -v "^#"; df -h /'
$B 'grep -nE "FAIL|ERROR" /var/log/backup.log | tail -10; tail -3 /var/log/backup.log'
$B 'for d in /root/backups/{pg,mongo,bench,appconfig,wasessions}/*/; do printf "%s %s\n" "$d" "$(ls -t "$d" | head -1)"; done'
$B 'systemctl is-active fluent-bit fail2ban netdata; fail2ban-client status sshd | tail -3'
$B 'ls /opt/backup /opt/backup/jobs; du -sh /var/tmp /var/lib/containerd 2>/dev/null'
ssh -o BatchMode=yes root@db "sudo -u postgres psql -XAt -c \"select datname from pg_database where datname ~ '^verify_'\""
```
