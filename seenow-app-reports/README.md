# seenow-app-reports

App-scoped reports for **seenow** — an AI-tutor LMS (github.com/biji-dev/seenow; Bun + Turbo
monorepo: `api`, `workers`, `web-public`, `web-learner`, `web-teach`, `web-b2b`, `web-admin`).
Upstream ships a Docker-Compose deploy; the dev environment runs **bare-metal** (system nginx +
PM2 + local Postgres/Redis) on the `dev` host — adapting the Compose topology, the same way
eventopia does.

## Deploy footprint (dev)

- **Host:** `dev` (`deploy@154.26.130.96`, Ubuntu 22.04.5), no Docker for seenow.
- **Domain:** `*.dev.seenow.ac` (Cloudflare grey / DNS-only → `154.26.130.96`). Subdomains:
  apex `dev.seenow.ac` + `www` → web-public (Next SSR); `api`; `learner`/`teacher`/`b2b`/`admin`
  → static Vite SPAs; `<tenant>.*` → web-learner with `X-Seenow-Tenant` (white-label).
  (`teach.dev.seenow.ac` 301-redirects to `teacher.dev.seenow.ac` — renamed in session-002.)
- **PM2 (user `deploy`, `/home/deploy/seenow.config.cjs`):** `seenow-api` `:4900` (Bun/Hono),
  `seenow-workers` (Bun, BullMQ on Redis db3), `seenow-web-public` `:4901` (Node `next start`,
  bound `127.0.0.1`). API binds `127.0.0.1:4900` (`API_HOST`, session-004).
- **Postgres 14** (local, `:5432`): db `seenow`, owner role `seenow` (`CREATEROLE`+`BYPASSRLS`,
  **not** superuser — migration/seed role), app role `seenow_app` (non-superuser, **RLS binds**).
  `vector 0.8.0` extension, 57 tables. **Redis** logical **db 3**.
- **Env:** `NODE_ENV=production`; AI = **Anthropic via Claude OAuth** (`EVAL_MODEL=claude-opus-4-8`);
  object storage **deferred** (S3 not consumed by current code); OTEL off. Cross-portal cookie on
  `.dev.seenow.ac`. Secrets in `~deploy/seenow/.env` (0600) + `/root/.seenow-secrets`.
- **TLS:** LE wildcard cert `seenow-dev` (`dev.seenow.ac` + `*.dev.seenow.ac`) via **DNS-01**
  (Cloudflare), creds `/etc/letsencrypt/cloudflare/seenow.ini` (seenow.ac token, **reusable for the
  `app`/prod deploy**). Auto-renew scheduled.

## Sessions

| # | Date | Topic | Key outcome |
| --- | --- | --- | --- |
| [001](session-001-2026-06-16.md) | 2026-06-16 | Initial **dev** deploy on `dev` (nginx + PM2, local PG14/Redis, seed) | All 8 hosts live over HTTPS; RLS gate 27/27; seeded course + 5 QA users; 3 PM2 procs, 0 restarts; wildcard cert via DNS-01 |
| [002](session-002-2026-06-16.md) | 2026-06-16 | Rename **teach portal → teacher** for naming consistency (PR [#1](https://github.com/biji-dev/seenow/pull/1)) | `web-teacher` + wire-key `"teacher"` + `teacher.dev.seenow.ac`; typecheck 16/16, tests 8/8; `/v1/me` returns `["learner","teacher"]`; legacy `teach.` 301s |
| [003](session-003-2026-06-16.md) | 2026-06-16 | **PRODUCTION** deploy on `app` (proxy-fronted cluster, DB on `db`, no seed) | **Live over HTTPS through CF** (orange/Full-strict); 8 hosts 200; RLS gate 27/27; 3 PM2 procs 0 restarts; LE `*.seenow.ac` wildcard via DNS-01 on proxy |
| [004](session-004-2026-06-17.md) | 2026-06-17 | API hardening on dev+prod (PRs [#2](https://github.com/biji-dev/seenow/pull/2)/[#3](https://github.com/biji-dev/seenow/pull/3)) | API bound to private IP (`10.0.0.5`/`127.0.0.1`); env-driven wildcard CORS + Better-Auth trust → tenant `*.seenow.ac` origins authenticate (dev: 200 + cookie) |
| [005](session-005-2026-06-24.md) | 2026-06-24 | **dev** redeploy + full DB reseed | Code/migrations already current (`1895e1e`, 16/16) → real work was a destructive wipe+reseed; `public` was owned by `postgres` (blocked `reset-db.ts`) — **reassigned to `seenow`**; `vector` re-created as superuser; RLS gate 27/27; 8 hosts 200; QA login ✓ |

## Production footprint (`app` / seenow.ac)

CF (**orange, Full-strict**) → `proxy` nginx (`/etc/nginx/sites-available/seenow.conf`, LE `*.seenow.ac`
cert via DNS-01, token `/etc/letsencrypt/cloudflare-seenow.ini`) → `app` `10.0.0.5:4900/4901` (PM2 under
**`devops`**, `~/seenow.config.cjs`; web-public + Bun API both bound `10.0.0.5` since session-004). The 4
Vite SPAs are static on **proxy** `/var/www/seenow/web-{learner,teacher,b2b,admin}`. DB+Redis on `db`
`10.0.0.1` (PG16.9, role `seenow` w/ `BYPASSRLS` + non-superuser `seenow_app`, pgvector 0.8.2, **Redis
db7**). AI = Anthropic Claude OAuth (reused from dev). **No seed.** Subdomains: apex→web-public, www→301
apex, `api`, `learner`/`teacher`/`b2b`/`admin`→static, `*.seenow.ac`→learner (`X-Seenow-Tenant`). CF DNS
records (apex/www/api/portals + `*`) pre-existed, orange → `46.250.234.153`.

## Open follow-ups

**Production:**
- ~~Bind the Bun API to `10.0.0.5`~~ — **done** (session-004, `API_HOST`; dev binds `127.0.0.1`).
- ~~Env-driven wildcard CORS for tenant `*.seenow.ac` origins~~ — **done** (session-004, `TENANT_ROOT_DOMAIN` + Better-Auth `trustedOrigins`).
- ~~Confirm CF zone SSL/TLS mode = Full (strict)~~ — **confirmed** by user.
- Swap the personal Claude OAuth token for a dedicated `ANTHROPIC_API_KEY` for production. *(deferred — OAuth fine for now)*
- Static redeploys: re-publish the 4 `dist/`s from app → proxy `/var/www/seenow/*`.

**Dev (session-001/002):**

- ~~`seenow-api` binds `0.0.0.0:4900`~~ — **done** (session-004): `API_HOST=127.0.0.1` via the new bind-address env.
- **AI (Anthropic OAuth) not yet exercised end-to-end** — config is in place but no live tutor call
  made. Validate with `bun run verify:gr:eval` or a real session (enroll → probe → tutor SSE).
- **Object storage deferred** — wire MinIO/S3 (`S3_*`) when upload/export/audit-archive features land.
- **Production deploy on `app`** (separate session) — proxy-fronted, DB on `db`. The same Cloudflare
  token (`seenow.ac`) works for the prod wildcard cert.

## Gotchas worth remembering

- **`bun db:migrate` runs via `--filter`, which switches cwd to `apps/api`** — Bun then loads
  `.env` from there (none), so `DATABASE_URL` falls back to the `:seenow` default and auth fails.
  Run the migrator from the repo root instead: `bun run apps/api/src/db/migrate.ts`.
- **Next/Vite read env from their own app dir**, not the monorepo root (turbo strict env doesn't
  forward `NEXT_PUBLIC_*`/`VITE_*`). Build-time env lives in `apps/web-public/.env.production` and
  `apps/web-{learner,teach,b2b,admin}/.env` — they bake the API base into the bundle.
- **PM2 ecosystem files must be named `*.config.cjs`** or PM2 runs them as a single script.
- **Reseeding (wipe + reseed) the dev DB** (session-005): seeds are **not idempotent**, so a reseed
  must wipe first. Dev `public` schema is now owned by **`seenow`** (was `postgres` — reassigned
  session-005), so `NODE_ENV=development bun run scripts/reset-db.ts` works (localhost → passes the
  `isLocal` check; the `NODE_ENV` override clears its prod-guard). Then `bun run
  apps/api/src/db/migrate.ts` (**keep prod env** — non-prod would reset the `seenow_app` password and
  break `APP_DATABASE_URL`) + `bun seed:content` + `bun seed:users` + `pm2 restart`. **Re-create the
  `vector` extension as `postgres` if you `drop schema public` directly** (it's untrusted). Never use
  the `bun db:reset` npm script — its `--filter` migrate loads the wrong `.env`.
