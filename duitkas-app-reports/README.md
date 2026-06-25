# duitkas App Reports

App-scoped reports for the **duitkas / baznas** product — an AI-powered WhatsApp expense/cash bot (repo `biji-dev/miaw-flow`, pnpm monorepo: Fastify API + WhatsApp bot + Socket.IO in `apps/api`, Next.js dashboard in `apps/web`). WhatsApp connectivity is via the `miaw-core` QR-scan provider; AI via Gemini (`gemini-2.5-flash`) with a Qwen fallback. The app integrates with the DuitKas API (`DUITKAS_API_KEY`).

This is **multi-tenant by instance**: each client gets its own folder / PM2 services / database / Redis db / WhatsApp pairing / `DUITKAS_API_KEY`, all private-bound on `app` and proxied at `<client>.duitkas.biji.uk`. Covers cross-server work: the services on `app`, public ingress on `proxy`, and databases on `db`.

**Per-client instances:**

| Client | Folder | PM2 | API/Web port | Postgres | Redis db | Domain | WhatsApp |
|---|---|---|---|---|---|---|---|
| baznas | `~/miaw-flow-baznas` | `miaw-{api,web}-baznas` | 7007 / 7008 | `miawflow_baznas` | db 0 | `baznas.duitkas.biji.uk` | `catatkas-bot` (paired) |
| lpekin | `~/miaw-flow-lpekin` | `miaw-{api,web}-lpekin` | 7018 / 7019 | `miawflow_lpekin` | db 5 | `lpekin.duitkas.biji.uk` | `lpekin-bot` (awaiting QR) |

**Server footprint:**
- `app` (`154.26.129.104` / `10.0.0.5`) — all instances under PM2 (`devops` user), Fastify API + WhatsApp + Socket.IO + Next.js dashboard. **Bound to the private interface (`10.0.0.5`) only** — no public port exposure.
- `proxy` (`46.250.234.153` / `10.0.0.2`) — one nginx vhost per client: path-routes `/socket.io/` + `/health` → API port, `/` → web port; Let's Encrypt cert per domain (nginx HTTP-01, auto-renew).
- `db` (`10.0.0.1`) — one PostgreSQL DB per client (`miawflow_<client>`, owner `miaw`); one Redis db index per client.

**DNS / TLS:** `*.duitkas.biji.uk` must stay **grey-cloud (DNS-only)** A → `46.250.234.153`. Cloudflare free Universal SSL does not cover the 2-level subdomain, so re-enabling the orange proxy breaks edge TLS.

**Adding a new client:** create `miawflow_<client>` (owner `miaw`) on db → clone repo to `~/miaw-flow-<client>`, set 3 `.env` (next free port pair, next free Redis db, `<client>-bot`, client key, `MIAW_SESSION_PATH=./data/sessions`) → rename PM2 procs → `pnpm install && build` → `db:migrate` (never `db:seed`) → `pm2 start && save` → proxy vhost + certbot → scan QR at `/onboarding`.

**Open follow-ups:**
- [ ] **lpekin:** pair WhatsApp — scan QR at `https://lpekin.duitkas.biji.uk/onboarding`.
- [ ] Delete the `*.bak-prebaznas` env/ecosystem backups on `app` once baznas is confirmed stable.
- [ ] Optional: clean up the pre-existing dangling `miaw-core` root symlink (real dependency is `node_modules/miaw-core`; the symlink is unused).

## Sessions

| # | Date | Topic | Key outcomes |
|---|------|-------|-------------|
| [001](session-001-2026-06-11.md) | 2026-06-11 | Rebrand `miaw-flow` → baznas + close public ports | Renamed folder/PM2/DB in place; rebound `7007/7008` to `10.0.0.5` (public closed); published `https://baznas.duitkas.biji.uk` via proxy (grey-cloud + LE cert, path-routed); WhatsApp session preserved (no QR re-scan) |
| [002](session-002-2026-06-11.md) | 2026-06-11 | New client instance: lpekin | Fresh clone `~/miaw-flow-lpekin`, new DB `miawflow_lpekin` (drizzle migrate), Redis db5, PM2 `miaw-{api,web}-lpekin` on private `7018/7019`, `https://lpekin.duitkas.biji.uk` (LE cert, path-routed); deployed unpaired (QR pending at `/onboarding`) |
| [003](session-003-2026-06-17.md) | 2026-06-17 | Deploy v0.4.1: per-tenant DuitKas categories + Redis namespacing | Both clients `0.4.0`→`0.4.1` (`b3b1c57`, already on `main`); categories now fetched from DuitKas API (live IDs, was stale hardcoded map) + `category_id` in requests; set `REDIS_KEY_PREFIX` (`baznas:`/`lpekin:`); no migrations, no code change (lpekin endpoint 404 → both use `/api/v1/baznas` default); health 200, WhatsApp sessions preserved |
