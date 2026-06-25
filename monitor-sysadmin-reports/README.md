# Monitor Server Sysadmin Reports

Session-based sysadmin reports for `root@monitor` (public IP `217.15.162.56`, internal `10.0.0.3`; QEMU/KVM VPS, Ubuntu 24.04.2 LTS).

Internal cluster **monitoring & analytics hub**. Hosts the Docker stacks behind `errors.biji.uk` (GlitchTip), `analytics.biji.uk` (OpenPanel), `status.biji.uk` (Uptime Kuma + Kuma-MCP), `monitor.biji.uk` (Netdata), and `vault.biji.uk` (Vaultwarden). All public traffic comes via `proxy` (10.0.0.2); stateful data lives on `db` (10.0.0.1: Postgres `glitchtip` + `openpanel`, Redis, ClickHouse).

| Session | Date | Topic | Status |
|---------|------|-------|--------|
| [Session 1](session-001-2026-05-19.md) | 2026-05-19 | Initial audit & hardening | Done |
| [Session 2](session-002-2026-05-19.md) | 2026-05-19 | OpenObserve install | Done |
| [Session 3](session-003-2026-05-24.md) | 2026-05-24 | Fluent Bit install — Docker container logs → OpenObserve | Done |
| [Session 4](session-004-2026-05-25.md) | 2026-05-25 | Fleet Overview dashboard in OpenObserve (14 panels, all 8 streams) | Done |
| [Session 5](session-005-2026-05-25.md) | 2026-05-25 | OpenObserve stream retention audit — explicit 7–30d per stream | Done |
| [Session 6](session-006-2026-05-25.md) | 2026-05-25 | Fleet-wide `syslog` stream — SSH + fail2ban + kernel from all 5 cluster servers | Done |
| [Session 7](session-007-2026-05-25.md) | 2026-05-25 | Fleet Overview dashboard — syslog panels 15–17 (SSH/UFW/Fail2ban by server) | Done |
| [Session 8](session-008-2026-05-25.md) | 2026-05-25 | OO alerts via Telegram — SSH brute-force, fail2ban, nginx 5xx, app stderr | Done |
| [Session 9](session-009-2026-06-22.md) | 2026-06-22 | Uptime Kuma update 2.1.3 → 2.4.0 (Docker `:2` tag, volume preserved) | Done |

## Open follow-ups (from session 008)

- Set `syslog` stream retention to 30 days — missed in session-005 (stream didn't exist yet). `PUT /api/default/streams/syslog/settings` `{"data_retention": 30}`.
- Extend SSH/fail2ban alerts to `numa` stream — `numa` ships to its own stream, not `syslog`; `SSH_Brute_Force_Burst` and `Fail2ban_IP_Ban` miss numa events. Add numa to syslog stream OR clone alerts on `numa` stream.
- Create OO ingest-only user — Fluent Bit configs on all 6 servers carry the admin password. Create a write-only OO user and rotate all `/etc/fluent-bit/fluent-bit.conf` configs.
- Tune `App_Stderr_Spike` threshold — hasn't fired at 100/5 min; calibrate against Fleet Overview `App Errors by Service` panel baseline.

## Open follow-ups (from session 001)

- Rotate `glitchtip`, `openpanel` Postgres + ClickHouse credentials on `db` and update env files + `backup`'s `/opt/backup/config.sh` together. Roll Vaultwarden `ADMIN_TOKEN` and Kuma admin password at the same time.
- Pin `vaultwarden/server` and `glitchtip/glitchtip` images to specific tags (currently `:latest`).
- Add a UFW or nftables default-deny INPUT layer (defense-in-depth on top of the now-internal Docker port bindings). Coordinate with Docker's iptables chains.
- Decide whether to bind sshd to `eth1` only (LAN/bastion access via `numa`).
- Confirm Netdata Cloud claim is intentional; unclaim if not.
- `monitor.biji.uk` is gated by nginx basic auth on `proxy` since session-001 (user `admin`, `/etc/nginx/.htpasswd-monitor`). Netdata 2.x 400-on-plain-curl persists — browsers fine. Rotate password periodically.
