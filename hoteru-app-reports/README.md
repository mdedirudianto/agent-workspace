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
  - **nginx** (session-007): private static file server for uploaded media, bound only to
    `10.0.0.5:8931`, serving `/var/lib/hoteru/uploads` (site `hoteru-uploads.conf`). The
    pre-existing `default` nginx site (public port 80) is disabled — this host has never served
    public HTTP directly and stays that way.
- **DB host:** `db` (`10.0.0.1`). Postgres 16 database `hoteru`, owner role `hoteru`.
  **Redis logical db 8** (`redis://10.0.0.1:6379/8`). 4 Prisma migrations applied (added
  `media_assets` in session-007).
- **Proxy:** `proxy` (`46.250.234.153` / `10.0.0.2`). nginx vhosts `hoteru.uk.conf` +
  `hoteru.co.id.conf`, each with a `/uploads/` location reverse-proxying to `10.0.0.5:8931`
  (session-007). Management SPA static at `/var/www/hoteru-app/`.
- **Uploads:** `/var/lib/hoteru/uploads/<hotelId>/<uuid>.<ext>` on `app`, shared across central and
  every tenant clone (isolated by `hotelId` subfolder, not by directory). Backend env needs
  `UPLOAD_ROOT=/var/lib/hoteru/uploads` + `UPLOAD_BASE_URL=https://api.<domain>/uploads` per
  instance. No backup coverage or orphan-cleanup job yet — see Open follow-ups.
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
- [ ] Technopark tenant guest-flow fixes from PR #2 (payment wording, scroll-to-top, proxy/cert
      workaround) landed on `hoteru_tpm`'s schema/code in session-004 but weren't feature-tested
      against `technoparkmalang.hoteru.co.id` — that verification is still owed.
- [ ] Delete or mark obsolete `hoteru.nginx.conf` / `runtime.sh` / `docs/deployment-technopark.md`
      in the repo — describe an unrelated single-VPS topology, caused confusion in both
      session-004 and session-005.
- [ ] New Technopark Premium Suite photo (session-006) only shows on newly-seeded/edited rows —
      existing seeded `room_types` row keeps the old photo until manually edited or re-seeded.
- [ ] Clean up the stale `web-proxy` entry in local `~/.ssh/known_hosts`/`/etc/hosts` (session-006:
      confirmed it's an unrelated host, not our `proxy` — just a confusing leftover).
- [ ] Central `~/hoteru`'s `apps/management/.env` got `VITE_PUBLIC_SITE_URLS` for the first time in
      session-006 — worth an interactive browser check of the affiliate referral-link display next
      time someone's in the management UI (only curl/build-verified so far).
- [ ] Bwalk Hotel Malang tenant landed on `main` in session-007 but is staging-only (`dev`) — not
      yet onboarded to production. Treat as a separate task, same shape as session-002's Technopark
      onboarding (new DB, nginx vhosts, DNS/certs, seed).
- [ ] `/var/lib/hoteru/uploads` on `app` (new in session-007) has no backup coverage and no
      orphan-cleanup job — add to the regular backup routine before real photography accumulates.
- [ ] `docs/agents/deploying-to-prod.md` (merged into `main` in session-007) describes the same
      unrelated single-VPS production target as `docs/deployment-technopark.md` above — now two
      docs in the repo pointing at infrastructure that isn't ours.

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 1](session-001-2026-06-16.md) | 2026-06-16 | Initial deploy (app+db+proxy) + hoteru.uk/.co.id proxy sites + wildcard TLS | Done |
| [Session 2](session-002-2026-06-18.md) | 2026-06-18 | First per-hotel tenant `technoparkmalang.hoteru.co.id` — dedicated clone/DB/backend, technopark booking site + mgmt SPA, minimal seed | Done |
| [Session 3](session-003-2026-07-16.md) | 2026-07-16 | `app.hoteru.uk` login fix — prod DB was never seeded, ran `db:seed`, verified in browser | Done |
| [Session 4](session-004-2026-07-25.md) | 2026-07-25 | Deployed PR #2 (multi-tenant, affiliates, gallery CMS) to central prod + Technopark Malang tenant; found tenant DB has no migration history (db-push only) | Done |
| [Session 5](session-005-2026-07-29.md) | 2026-07-29 | Fixed Technopark referral redirect (dinoudon.my.id → technoparkmalang.hoteru.co.id); permanently fixed recurring git fetch-refspec bug on tenant clone | Done |
| [Session 6](session-006-2026-07-31.md) | 2026-07-31 | Redeployed central `~/hoteru` + Technopark tenant to latest main (currency Rp fix, new photo); properly fixed the fetch-refspec bug for good; resolved proxy-access blocker (unrelated host, not a real issue) | Done |
| [Session 7](session-007-2026-08-12.md) | 2026-08-12 | Redeployed central + Technopark to latest main (25 commits); shipped real image uploads end-to-end, incl. new private nginx static server on `app` + `/uploads/` reverse-proxy on `proxy` to bridge the two-host topology | Done |
