# Proxy Server Sysadmin Reports

Session-based sysadmin reports for `root@proxy` (46.250.234.153 — KVM VPS, Ubuntu 24.04.3 LTS).

Public-facing nginx reverse proxy for the internal cluster (`10.0.0.0/22`). Terminates TLS for all production domains and routes traffic to `app (10.0.0.5)`, `monitor (10.0.0.3)`, and `erp (10.0.0.6)`.

| Session | Date | Topic | Status |
|---------|------|-------|--------|
| [Session 1](session-001-2026-05-12.md) | 2026-05-12 | Initial audit & nginx proxy map | Done |
| [Session 2](session-002-2026-05-12.md) | 2026-05-12 | Hardening & cleanup + asiaweek.uk coming-soon page | Done |
| [Session 3](session-003-2026-05-24.md) | 2026-05-24 | Fluent Bit install — nginx logs → OpenObserve | Done |
| [Session 4](session-004-2026-07-14.md) | 2026-07-14 | Fail2ban lockout diagnosis & fix — unbanned user IP + app internal IP, added `10.0.0.0/24` to `ignoreip` | Done |
