# miaw-route App Reports

App-scoped reports for **miaw-route** — WhatsApp Cloud API webhook router.

**Repo:** `git@github.com:biji-dev/miaw-route.git`
**Production URL:** https://routes.biji.uk
**Stack:** Bun 1.3.14 + Elysia + PostgreSQL + Redis

**Servers involved:**
- `app` (`154.26.129.104`) — **systemd service** `miaw-route` (Bun, port 9001; migrated off PM2 in session-008 — use `systemctl`, not `pm2`)
- `proxy` (`46.250.234.153`) — nginx vhost + SSL
- `db` (`109.123.233.215`) — PostgreSQL `miaw_route` DB + Redis DB1

---

## Sessions

| # | Date | Topic | File |
|---|------|-------|------|
| 1 | 2026-06-03 | Production deploy: app server (PM2 + Bun), proxy nginx + SSL, DB on db server | [session-001-2026-06-03.md](session-001-2026-06-03.md) |
| 2 | 2026-06-04 | Redeploy `4ad5288`→`882c050`: observability (GlitchTip + OpenObserve) + WABA Calling API + dashboard webhook config | [session-002-2026-06-04.md](session-002-2026-06-04.md) |
| 3 | 2026-06-05 | Redeploy `83e896c`→`773d064` (v0.9.4): WABA-level webhook forwarding + GlitchTip error reporting + viewer-local timestamps | [session-003-2026-06-05.md](session-003-2026-06-05.md) |
| 4 | 2026-06-06 | Redeploy `773d064`→`89c5101` (v0.9.5): webhook-reconciler worker + **timestamp→timestamptz DB migration** (instant-preserving, TZ Asia/Singapore) | [session-004-2026-06-06.md](session-004-2026-06-06.md) |
| 5 | 2026-06-08 | Redeploy `bb45dce`→`8ab6ae0` (v0.9.7): default route **webhook.site → local echo sink** (`localhost:9001/echo`); admin-auth gate on `GET`/`DELETE /echo` | [session-005-2026-06-08.md](session-005-2026-06-08.md) |
| 6 | 2026-06-08 | DB-only: **GroBiz + PasarBesar routes → local backends** (`localhost:4000` / `10.0.0.5:7002`, both `/api/webhooks/whatsapp`); fixed pasarbesar wrong path; flagged pasarbesar zero-traffic WABA | [session-006-2026-06-08.md](session-006-2026-06-08.md) |
| 7 | 2026-06-08 | **Standardized all 3 routes on `10.0.0.5:PORT`**; rebound grobiz-api `0.0.0.0`→`10.0.0.5` (HOST env, off public NIC) + fixed its localhost self-health-check (grobiz `2d7a1a9`) | [session-007-2026-06-08.md](session-007-2026-06-08.md) |
| 8 | 2026-06-08 | Diagnosed high Bun CPU (PM2 fork busy-loop: 67% futex/sched_yield); **migrated miaw-route PM2 → systemd** — CPU **23.3%→9.8%** (~58%). Now `systemctl`, not `pm2` | [session-008-2026-06-08.md](session-008-2026-06-08.md) |
