# App Server Sysadmin Reports

Session-based sysadmin reports for `root@app` (154.26.129.104 — KVM VPS, Ubuntu 24.04.4 LTS).

| Session                                | Date       | Topic                          | Status |
|----------------------------------------|------------|--------------------------------|--------|
| [Session 1](session-001-2026-05-12.md) | 2026-05-12 | Initial server audit           | Done   |
| [Session 2](session-002-2026-05-24.md) | 2026-05-24 | Fluent Bit install — PM2 logs → OpenObserve | Done   |
| [Session 3](session-003-2026-06-08.md) | 2026-06-08 | SSH "ban" misdiagnosis (use `devops@app`) + fleet-wide fail2ban office-IP whitelist | Done   |
| [Session 4](session-004-2026-06-17.md) | 2026-06-17 | `routes.biji.uk` login 504s → host swap-thrash from ytgrab-api 2.5 GB leak; restart + `max_memory_restart` cap | Done   |
| [Session 5](session-005-2026-07-22.md) | 2026-07-22 | `admin.wagrab.com` 502 → Node 22→24 broke `isolated-vm` in `wagrab-admin`/`feyfa-admin`; pinned both to Node 22 via nvm; paused `foucher-admin.conf` (domain renewal pending) | Open follow-ups |

## Open follow-ups

- **Fleet-wide Node 24 native-module risk scan** — session 5 only checked for apps that already failed with the exact `isolated-vm` ABI error. Still need to proactively scan the other ~35 PM2 apps' `node_modules` for native addons and restart them one by one (verifying each) to catch any other latent Node 24 breakage.
- **`foucher-admin.conf`** — disabled at `proxy` (`sites-enabled` symlink removed) pending the user renewing the `foucher.co` domain. Re-enable once renewed: re-link into `sites-enabled`, `nginx -t && systemctl reload nginx`.
