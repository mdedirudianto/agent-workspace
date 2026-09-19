# avilia-app-reports

App-scoped reports for **avilia** — the affiliate operating system that Hoteru reports booking
events to (github.com/biji-dev/avilia; pnpm + Turborepo monorepo, Node 22+).

Two deployable apps (`apps/`): `backend` (Fastify 5 + Prisma 6 API, 22 models) and `portal`
(Vite + React 19 SPA — ops / hotel-service / affiliate console). `packages/` holds shared
`types`, `utils`, `config`.

**No Redis** — unlike hoteru, nothing in the codebase uses it. Postgres is the only datastore.

## Deploy footprint (production, since session-001)

- **App host:** `app` (`devops@154.26.129.104` / `10.0.0.5`, Ubuntu 24.04), PM2, `/home/devops/avilia` @ `main`.
  - `avilia-api` — Fastify backend, **private-bound `10.0.0.5:3140`** (fork mode, cwd `apps/backend`,
    loads `apps/backend/.env` via its own dotenv). Port 3140 sits just past hoteru's 3110–3131 block.
  - `portal` is **not** a process — built to static and served from `proxy`.
- **DB host:** `db` (`10.0.0.1`). Postgres 16 database `avilia`, owner role `avilia`. 6 Prisma
  migrations / 23 tables. **No Redis logical db** (unused by this app).
- **Proxy:** `proxy` (`46.250.234.153` / `10.0.0.2`). nginx vhost `avilia.id.conf`; portal static at
  `/var/www/avilia-app`, apex/www holding page at `/var/www/avilia.id`.
- **DNS:** Cloudflare, **orange-cloud (proxied)**, SSL/TLS **Full (strict)**. `avilia.id`, `www`,
  `app`, `api` → origin `46.250.234.153`.
- **TLS:** one LE cert via **HTTP-01 webroot** (`/var/www/certbot`) covering all 4 names —
  **not** a wildcard, and **no Cloudflare API token exists for this zone**. Adding a subdomain means
  re-issuing with an extra `-d`. Renewal relies on Cloudflare continuing to pass plain HTTP through;
  enabling "Always Use HTTPS" on the zone would break it (→ switch to DNS-01).

### Staging (separate, pre-existing)

`*.dev.avilia.id` on the shared dev box (`deploy@154.26.130.96`, `/home/deploy/avilia`, port 4030).
Untouched by production work. Note `/home/deploy` is **dev only** — production uses `/home/devops`.

## Subdomain map

| Host | → | Service | Backend |
| --- | --- | --- | --- |
| `api.avilia.id` | proxy | API (`/health`, `/api/*`) | `avilia-api` `:3140` |
| `app.avilia.id` | static + proxy | portal SPA; `/api/` same-origin proxy | `/var/www/avilia-app` |
| `avilia.id`, `www.avilia.id` | static | ID holding page ("Segera Hadir") | `/var/www/avilia.id` |

The portal calls a **relative `/api`**, so there is no build-time API base — the `app` vhost proxies
`/api/` to the backend. Changing the API host needs no rebuild.

## Hoteru ↔ Avilia integration — LIVE on both tenants (session-002)

Direction is **one-way: Hoteru → Avilia** (HMAC-signed booking events + affiliate sync). Avilia
never calls Hoteru's API. The only reverse link is the promo URL (`/r/<slug>`) the portal shows
affiliates.

**Live since 2026-09-19** on the two dedicated Hoteru tenants:

| Service | Hotel | Master rate | Affiliates backfilled |
| --- | --- | --- | --- |
| `svc_bwalk` | Bwalk Hotel Malang (`bwalk.hoteru.co.id`) | 1500 bps | 105 (all 10%) |
| `svc_technopark` | Technopark Malang (`technoparkmalang.hoteru.co.id`) | 1500 bps | 12 (1×0%, 9×1%, 2×10%) |

Each tenant's hoteru `.env` carries `AVILIA_ENABLED=true`, its own `AVILIA_SERVICE_ID` +
`AVILIA_SERVICE_SECRET`, and `AVILIA_EVENTS_URL=http://10.0.0.5:3140/api/service-events/events` —
the **private** URL, since both apps run on `app` (skips the Cloudflare hairpin; payloads are
HMAC-signed regardless).

**Central `~/hoteru` is deliberately unwired** — it serves 3 hotels from one process, so a single
`service_id` would conflate them.

Hoteru's `CommissionService` stays authoritative; Avilia is a **shadow ledger** during the pilot.
No payout authority has moved.

**Gotcha:** only affiliate *creation* syncs to Avilia. A commission-rate edit in Hoteru does **not**
propagate — re-run the (idempotent) backfill after rate changes.

## Open follow-ups

- [ ] Back up `SECRET_ENCRYPTION_KEY` + DB password to Vaultwarden — it encrypts every hotel webhook
      secret and exists only in `apps/backend/.env` on `app`. Losing it means re-provisioning all hotels.
- [ ] Add the `avilia` DB to the `db`→`backup` pull schedule (no backup coverage yet).
- [ ] Add an Uptime Kuma monitor for `https://api.avilia.id/health`.
- [x] Fixed the 5 integration blockers, provisioned both hotels and wired both tenants (session-002).
- [x] Backfilled all 117 existing hoteru affiliates via `affiliate-sync` with their real rates.
- [ ] **`aff123`**: 117 affiliate accounts share this default password. Needs a real invite/reset
      flow before affiliates are pointed at the portal — biggest remaining risk in the integration.
- [x] **15% master rate confirmed** by the user on 2026-09-20 — "for now", i.e. a standing pilot
      figure rather than a per-hotel signed agreement. Technopark's 1% affiliates still imply a 14%
      platform margin; revisit per hotel if a real agreement lands.
- [ ] Watch for the **first real attributed booking** (expect 1 transaction + 2 ledger entries,
      `pending` → `payable` on check-out). Avilia held 0 transactions at end of session-002.
- [ ] No **rate-change propagation**: Hoteru syncs only on affiliate creation. Re-run the backfill
      after rate edits, or add an update hook upstream.
- [ ] Upstream: `config.ts` silently falls back to the committed dev `JWT_SECRET` /
      `SECRET_ENCRYPTION_KEY` when unset — needs a fail-fast production boot guard.
- [ ] Upstream: `docs/operations/deployment.md` + `docs/agents/deploying-to-prod.md` +
      `ecosystem.config.cjs` describe a single-VPS target that isn't our infra (same recurring trap
      as hoteru's repo docs).
- [x] Upstream: repaired the 3 stale integration tests (session-002, PR #1).
- [ ] Human browser pass on the authenticated portal — session-001 verified auth by API token only.
- [ ] Rotate the bootstrap `admin@avilia.id` password after first real login.

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 2](session-002-2026-09-19.md) | 2026-09-19 | Hoteru↔Avilia wiring: fixed 5 blockers (staging promo links, ignored partner rates, silent webhook rejections, 0%-rate coercion, stale tests) across avilia PR #1 + hoteru PR #22; provisioned both hotels, backfilled 117 affiliates, wired Bwalk + Technopark live | Done |
| [Session 1](session-001-2026-09-19.md) | 2026-09-19 | Initial production deploy across app+db+proxy — PM2 `avilia-api` :3140, Postgres `avilia`, portal SPA + apex holding page on proxy, 4-name LE cert (HTTP-01), admin bootstrap without demo seed; Hoteru integration analysed but deliberately left unwired | Done |
