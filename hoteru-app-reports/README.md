# hoteru-app-reports

App-scoped reports for **hoteru** — a hotel management platform for independent hotels
(github.com/biji-dev/hoteru; pnpm + Turborepo monorepo). Two-domain product:

- **hoteru.uk** — product/marketing/demo umbrella (English-first).
- **hoteru.co.id** — Indonesia. Apex = marketing landing; **`<hotel>.hoteru.co.id` is reserved
  per-hotel** (one subdomain per Indonesian hotel) — see the tenancy note below.

The four live monorepo apps (`apps/`): `backend` (Fastify 5 + Prisma 6 API), `public`
(Next.js 15 SSR — guest/landing site), `marketing` (Next.js 15 + next-intl — marketing site,
EN/ID), `management` (Vite + React-Router SPA — back-office). `legacy-backend`/`legacy-frontend`
are not deployed.

## Deploy footprint (production)

- **App host:** `app` (`devops@154.26.129.104` / `10.0.0.5`, Ubuntu 24.04), PM2, `~/hoteru` @ `main`.
  Three Node processes, private-bound to `10.0.0.5`:
  - `hoteru-api` — backend Fastify, `:3110` (cwd `apps/backend`, loads `.env` via `dotenv/config`).
  - `hoteru-public` — `public` Next standalone, `:3111` (`HOSTNAME=10.0.0.5 PORT=3111`).
  - `hoteru-marketing` — `marketing` Next standalone, `:3112` (`HOSTNAME=10.0.0.5 PORT=3112`).
  - `management` SPA is **not** a process — built to static and served from `proxy`.
- **DB host:** `db` (`10.0.0.1`). Postgres 16 database `hoteru`, owner role `hoteru`.
  **Redis logical db 8** (`redis://10.0.0.1:6379/8`). 3 Prisma migrations applied.
- **Proxy:** `proxy` (`46.250.234.153` / `10.0.0.2`). nginx vhosts `hoteru.uk.conf` +
  `hoteru.co.id.conf`. Management SPA static at `/var/www/hoteru-app/`.
- **DNS:** Cloudflare, **orange-cloud (proxied)**. `hoteru.uk` + `www` + `*.hoteru.uk` and
  `hoteru.co.id` + `www` + `*.hoteru.co.id` already point at origin `46.250.234.153`.
  CF SSL/TLS mode must be **Full (strict)** (set in dashboard; the API token is DNS-scoped only).
- **TLS:** two LE **wildcard** certs via **DNS-01** (Cloudflare): cert `hoteru.uk`
  (`hoteru.uk` + `*.hoteru.uk`) and cert `hoteru.co.id` (`hoteru.co.id` + `*.hoteru.co.id`).
  Token at `/etc/letsencrypt/cloudflare/hoteru.ini` (0600). Auto-renew via the apt certbot timer.

## Subdomain map

| Host | → | Service | Backend |
| --- | --- | --- | --- |
| `hoteru.uk`, `www.hoteru.uk` | proxy | marketing home (next-intl EN/ID) | `marketing` `:3112` |
| `demo.hoteru.uk` | proxy | demo guest/landing site | `public` `:3111` |
| `app.hoteru.uk` | static | demo management app (SPA) | `/var/www/hoteru-app` |
| `api.hoteru.uk` | proxy | API (Scalar docs at `/docs`, `/health`) | `backend` `:3110` |
| `hoteru.co.id`, `www.hoteru.co.id` | proxy | marketing landing (ID locale) | `marketing` `:3112` |
| `<hotel>.hoteru.co.id` | static | **reserved** — ID "coming soon" holding page | _(holding, except live tenants below)_ |
| `technoparkmalang.hoteru.co.id` | proxy | **LIVE tenant** — Technopark Malang booking site | dedicated clone `:3121` (session-002) |
| `app.technoparkmalang.hoteru.co.id` | static | tenant management SPA | `/var/www/hoteru-tpm-app` |
| `api.technoparkmalang.hoteru.co.id` | proxy | tenant backend API | dedicated clone `:3120` |

## ⚠️ Per-hotel tenancy (`<hotel>.hoteru.co.id`) — convention to honor

The plan: **one subdomain per Indonesian hotel** under `hoteru.co.id`. As of session-001 the
**app code does not implement host→hotel routing** — no Next middleware, no `req.headers.host`
tenant resolution — and both frontends bake their API URL at **build time** (`NEXT_PUBLIC_API_URL`,
`VITE_API_BASE_URL`), so one build can't serve many tenant backends. The `*.hoteru.co.id` wildcard
cert is issued and the wildcard vhost returns a holding page, so onboarding a hotel is DNS-free
(already wildcarded). **Going live per-hotel requires app work first:** host→hotel resolution
middleware, per-host/runtime API base, and CORS for tenant origins. Do not wire tenant subdomains
to the `public` site until that lands.

**Update (session-002):** the first live tenant (`technoparkmalang.hoteru.co.id`) is deployed via a
different model — a **dedicated full clone per hotel** (own repo clone, backend process, Postgres DB,
Redis db, JWT secrets, TLS), using the **`feat/integration-area-a-b`** branch which adds the bespoke
guest site `apps/web/technopark/` + an `x-hotel-id`-header multi-tenant backend. Each tenant bakes its
API base + hotel id at build time. This is the working onboarding path today; shared host→hotel
routing on one build is still the longer-term alternative. Note: **2-level** tenant subdomains
(`api.`/`app.<hotel>`) can't be CF-orange on the free plan (Universal SSL covers only one level) —
they're grey-cloud (DNS-only) over the proxy's LE cert; the `<hotel>` apex stays orange.

## Open follow-ups

- [ ] App-side multi-tenancy for `<hotel>.hoteru.co.id` (above) — next milestone.
- [ ] Confirm CF SSL/TLS mode = **Full (strict)** on both zones (manual; token can't read it).
- [ ] Marketing locale on `.co.id`: next-intl auto-detects (curl with no `Accept-Language` → `/en`).
      Confirm `.co.id` defaults to ID for real visitors, or force ID per-domain if desired.
- [ ] Payment gateways (Midtrans/Xendit) left unconfigured — add keys to `apps/backend/.env` when needed.

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 1](session-001-2026-06-16.md) | 2026-06-16 | Initial deploy (app+db+proxy) + hoteru.uk/.co.id proxy sites + wildcard TLS | Done |
| [Session 2](session-002-2026-06-18.md) | 2026-06-18 | First per-hotel tenant `technoparkmalang.hoteru.co.id` — dedicated clone/DB/backend, technopark booking site + mgmt SPA, minimal seed | Done |
| [Session 3](session-003-2026-07-16.md) | 2026-07-16 | `app.hoteru.uk` login fix — prod DB was never seeded, ran `db:seed`, verified in browser | Done |
