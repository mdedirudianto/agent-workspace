# Backup Server Sysadmin Reports

Session-based sysadmin reports for `root@backup` (public IP `194.233.81.93`, internal `10.0.0.4`; KVM VPS, Ubuntu 22.04.5 LTS).

Dedicated **backup target** for the internal cluster. Pulls daily PostgreSQL + MongoDB dumps from `db` (10.0.0.1) and ERPNext bench backups from `erp` (10.0.0.6) via `/opt/backup/` cron jobs; stores them locally under `/root/backups/`. Currently no offsite replication — see open follow-ups.

**grobiz backup jobs** (added 2026-06-07, app-scoped — documented in [grobiz-app-reports/session-006](../grobiz-app-reports/session-006-2026-06-07.md)): `backup-grobiz.sh` runs every 6h (`0 0,6,12,18` WIB) and adds `jobs/grobiz-pg.sh` (Postgres `grobiz`), `jobs/grobiz-sites.sh` (per-tenant ERPNext sites, dynamic enum), `jobs/grobiz-appconfig.sh` (app `.env` via forced-command key). GFS retention (4 intraday + 7 daily + 4 weekly) lives in `rotate.sh`; non-destructive grobiz checks in `verify.sh`. New backup→app SSH path uses the existing `backup-pull@backup` key, locked to `from=10.0.0.4` + forced `cat .env`.

| Session | Date | Topic | Status |
|---------|------|-------|--------|
| [Session 1](session-001-2026-05-17.md) | 2026-05-17 | Initial audit & hardening | Done |
| [Session 2](session-002-2026-05-25.md) | 2026-05-25 | Fluent Bit install — backup jobs + syslog → OpenObserve (`backup` stream, 30d retention) | Done |
| [Session 3](session-003-2026-06-20.md) | 2026-06-20 | Tier 2 backup coverage gap — fixed broken `miawflow` job, switched Tier 2 to **auto-discovery** (9 prod DBs were unbacked-up); verified restores; routine dumps moved to least-priv `backup_reader` | Done |

## Open follow-ups (from session 001)

- Set up offsite backup replication (rclone → S3-compatible, restic, or BorgBase). Currently local-only — single point of failure.
- Encrypt backups at rest (or migrate to a tool like restic that gives offsite + encryption + dedup together).
- ~~Replace `postgres` superuser in `/opt/backup/config.sh` with a least-privileged `backup_reader` role on `db`.~~ **Done session 003** — routine dump jobs run as read-only `backup_reader` (read-all + BYPASSRLS, no super/createdb); `verify.sh` keeps `PG_ADMIN_USER=postgres` only for temp-DB create/restore/drop.
- Decide whether to bind SSH to `eth1` only (LAN/bastion access) instead of leaving it on the public IP behind key-only + fail2ban.
- ~~Run `verify.sh` manually once and confirm `db` lets backup→PG create the temp verification DBs before trusting the weekly cron.~~ **Done session 003** — `verify.sh seenow` restored 57 tables and dropped the temp DB cleanly.
- Consider removing NetworkManager (systemd-networkd already handles both interfaces).
