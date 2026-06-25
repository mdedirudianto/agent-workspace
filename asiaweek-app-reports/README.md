# asiaweek App Reports

App-scoped reports for the **asiaweek** product (`dev.asiaweek.uk`).
Covers cross-server work: deployments, env/secret management, schema migrations, domain changes, version bumps.

**Server footprint:**
- `dev` (`154.26.130.96`) — pnpm monorepo, 3 PM2 processes (web :6001, app :6002, api :6003), nginx + SSL

**Tech stack:**
- `apps/web` — Astro 6 (static+SSR, Node adapter) → `https://dev.asiaweek.uk`
- `apps/app` — React Router v7 (full SSR) → `https://app.dev.asiaweek.uk`
- `apps/api` — Hono + pg-boss → `https://api.dev.asiaweek.uk`
- Database: local Postgres (`asiaweek` user, `asiaweek` db), Drizzle ORM migrations

**Current prod SHA:** `b43c83d` (2026-06-03) — observability merge, `NODE_ENV=production`

**⚠️ Production clean-up items pending (see session-003):**
- [x] `NODE_ENV` → `production` — done session-003 (2026-06-03)
- [x] Rotate `BETTER_AUTH_SECRET` — done session-003 (2026-06-03)
- [x] Set `RESEND_API_KEY` — done session-003 (2026-06-03); api `notification.send` now sends
- [ ] Remove dev seed accounts before public launch

**Open follow-ups:**
- [x] Add `asiaweek-*` to OpenObserve fleet monitoring — done session-003 (stream `asiaweek_api`, org `default`)
- [ ] Add CSP `report-uri`/`report-to` header for GlitchTip security endpoints (projects 6/7/8) — no CSP policy exists yet
- [ ] Backfill observability wiring on **dev** (separate GA/OpenPanel ids to avoid cross-counting)
- [ ] Wire `RESEND_API_KEY` when email sending is needed on dev
- [ ] Consider running seed idempotently on each redeploy (currently only run once)

## Sessions

| # | Date | Topic | Key outcomes |
|---|------|-------|-------------|
| [001](session-001-2026-05-28.md) | 2026-05-28 | Initial dev deployment | Postgres DB, 3 PM2 processes, 3 nginx vhosts + SSL, migrations + seed — all green |
| [002](session-002-2026-05-28.md) | 2026-05-28 | Production deployment | Git clone, DB on db server, proxy nginx replaced static→proxy, SSL for app+api subdomains, seed+demo — all green |
| [003](session-003-2026-06-03.md) | 2026-06-03 | Observability + prod cutover | GA4 + OpenPanel + GlitchTip (6/7/8) + OpenObserve (`asiaweek_api`) wired; `NODE_ENV→production`; all 4 tools verified |
