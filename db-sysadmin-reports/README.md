# db-sysadmin-reports

Sysadmin sessions for `root@db` — the database server at `db.biji.uk` (`109.123.233.215`), Ubuntu 22.04.5 LTS, fronted by Cloudflare.

This server hosts all primary databases for the platform: PostgreSQL 16, MariaDB 10.6.22, MongoDB 8.0.10, ClickHouse 26.1.3.52, and Redis 8.6.1. Admin panels (phpMyAdmin, pgAdmin4, Mongo Express) are proxied through Apache2 at `https://db.biji.uk`.

## Sessions

| # | Date | Topic | Outcome |
|---|------|-------|---------|
| [001](session-001-2026-05-05.md) | 2026-05-05 → 2026-05-06 | Initial audit & hardening | Renewed SSL (DNS-01/Cloudflare), locked origin to Cloudflare IPs only, restricted Netdata to LAN, moved Mongo Express off root, added 4 GB swap, documented MariaDB credentials, disabled unused PgBouncer, replaced default Apache homepage, bound PostgreSQL to private interfaces only, rotated shared MariaDB password, dropped orphan MariaDB user |
| [002](session-002-2026-05-24.md) | 2026-05-24 | Fluent Bit install — DB logs → OpenObserve | PostgreSQL, MongoDB, ClickHouse, Redis, MariaDB all shipping to stream `db` on OpenObserve |
| [003](session-003-2026-06-20.md) | 2026-06-20 | PostgreSQL fd-utilization alert (96.6%) | Benign false alarm — soft `LimitNOFILE` 1024 vs `max_files_per_process` 1000; raised to 65536 via systemd drop-in + restart, verified healthy |

## Open follow-ups (carried from session 001)

- Reconsider 6 stale MariaDB admin grants for non-UFW hosts (audited 2026-05-05, kept for now); if `monitor` needs MariaDB metrics, add a read-only user instead
- Monitor `wagrab` PostgreSQL DB growth (89 GB on a 490 GB disk)
- Tighten PostgreSQL `pg_hba.conf` — line `host all all 109.123.233.215/21 md5` allows the entire datacenter /21 (~8192 IPs); now redundant since the public listener was removed, but should be deleted for hygiene
