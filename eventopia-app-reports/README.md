# eventopia-app-reports

App-scoped reports for **eventopia** — an organizer-first, WhatsApp-native, QRIS-first event
platform (github.com/biji-dev/eventopia; pnpm/turbo monorepo: `api`, `workers`, `web-public`,
`console`, `admin` (operator console), `checkin`). Upstream ships a Docker-Compose deploy; the dev
environment runs **bare-metal** (system nginx + PM2 + local Postgres/Redis) on the `dev` host.

## Deploy footprint (dev)

- **Host:** `dev` (`deploy@154.26.130.96`, Ubuntu 22.04), no Docker.
- **Domain:** `*.dev.eventopia.my` (Cloudflare grey/DNS-only). Subdomains: `www` (web-public
  landing), apex→www, `<org>.*` (tenant routing → web-public), `api`, `app` (console),
  `checkin` (static PWA).
- **PM2 (user `deploy`):** `eventopia-api` `:38001` (Bun), `eventopia-workers` (Bun, metrics
  `:9091`), `eventopia-wa-stub` `:4111` (Bun), `eventopia-web-public` `:38100` (Node standalone),
  `eventopia-console` `:38200` (Node standalone). Config: `~/eventopia/ecosystem.config.cjs`.
- **Postgres 14** (local): db `eventopia`, role `eventopia`/`pgdev123` — **owns `public` schema,
  member of `app_tenant`, has `BYPASSRLS`** (the app assumes a superuser-equivalent connection).
  pgvector enabled. **Redis** db 2.
- **Env:** `dev` with third-party doubles (fake payments/AI, WA Graph stub), seeded org
  `kopikita-e2e`. TLS via LE cert `eventopia-dev` (HTTP-01, multi-SAN).

## Sessions

| # | Date | Topic | Key outcome |
| --- | --- | --- | --- |
| [001](session-001-2026-06-12.md) | 2026-06-12 | Initial **dev** deploy on `dev` (nginx + PM2, local PG/Redis, seed) | All 6 hosts live over HTTPS; 31 migrations; seeded org + paid ticket; 5 PM2 procs, 0 restarts |
| [002](session-002-2026-06-12.md) | 2026-06-12 | **Production** deploy on `app` (proxy-fronted, DB on `db`, no seed) | **Live over HTTPS** through CF (4 PM2 procs, 31 migrations, LE wildcard via DNS-01); patches committed to `main` (`a289aaa`); provider creds + rate config pending |
| [003](session-003-2026-06-17.md) | 2026-06-17 | **`eventopia.co.id`** public marketing face (proxy + cert + DNS; `.my` apex/www → co.id) | Marketing split onto co.id via `MARKETING_HOST` middleware (`3531450`), same web-public instance; LE cert DNS-01 (exp 2026-09-15); `.my` stays the organizer/attendee app — all surfaces green |
| [004](session-004-2026-06-20.md) | 2026-06-20 | Pull `main` forward (console **event-workspace** redesign) to **dev + prod** | dev `b0b75e6`→`1d7cc57` (34 commits), prod `a289aaa`→`1d7cc57` (33); **no DB migration/backfill** (same 31 migrations); superseded local patches stashed, clones now drift-free on env-driven `main`; web-public+console rebuilt clean; all surfaces green both envs |
| [005](session-005-2026-06-24.md) | 2026-06-24 | Pull `main` (**operator console**) to **dev** + full reseed (showcase seeds) | dev `1d7cc57`→`f812ca3` (63 commits); **+36 migrations** (31→67, `oc_*`); new app `apps/admin` deployed first time → **`operator.dev.eventopia.my`** (PM2 :38400, nginx vhost, cert expanded to 8 SANs); **DB wiped** (kept `platform_rate_config`) + Redis db2 flushed, reseeded **organizer + operator showcase only** (7 operators / 18+1 orgs, organizer 44/44); operator login verified (JWT); all surfaces green |
| [006](session-006-2026-07-09.md) | 2026-07-09 | Pull `main` (**multi-gateway payments + operator console**) to **prod** | prod `1d7cc57`→`2e3994a` (132+ commits); **+40 migrations** (31→71); DOKU+Midtrans payment gateways live (Xendit still unconfigured, no prod keys); operator console deployed to prod first time (`operator.eventopia.my`, PM2 :38400, no cert change — covered by existing wildcard); real `SUPER_ADMIN` bootstrapped (`hi@eventopia.my`); hotfixed a new prod-only fail-closed check (`OPERATOR_PREVIEW_SECRET`) that crash-looped `eventopia-api`; all surfaces green both domains |
| [007](session-007-2026-07-09.md) | 2026-07-09 | **WhatsApp/miaw-route refactor** + `.env` cleanup, **dev + prod** | `2e3994a`→`3f2c631` (5 commits, no frontend changes); migration 0071 drops dead `verify_token` column (72 total); eventopia's own Meta webhook verify-handshake removed — miaw-route now owns verification/forwarding (fleet convention); removed 4 dead `.env` vars (`META_WEBHOOK_VERIFY_TOKEN`/`META_WABA_ID`/`META_BUSINESS_ACCOUNT_ID`/`WEB_DATA_SOURCE`) on both envs; miaw-route app+route registration left to user (dashboard); all surfaces green both envs |

## Production footprint (`app` / eventopia.my + eventopia.co.id)

CF (orange, **Full-strict**) → `proxy` nginx → `app` `10.0.0.5:380xx` (PM2 under `devops`, Next bound
`10.0.0.5`). DB+Redis on `db` `10.0.0.1` (PG16, role `eventopia` w/ `BYPASSRLS`, **Redis db6**). Bun +
pgvector installed as prereqs. No seed. checkin static served from proxy. **71 migrations applied
(session-006).**

**Operator console (session-006):** `operator.eventopia.my` → `app` `10.0.0.5:38400` (PM2
`eventopia-operator`, admin standalone), covered by the existing `*.eventopia.my` wildcard cert (no
cert change needed). MFA off, no IP allowlist — internet-reachable, password-only login. First real
account: `hi@eventopia.my` (`SUPER_ADMIN`).

**Payments (session-006):** DOKU + Midtrans live (`PAYMENTS_DEFAULT_GATEWAY=midtrans`); Xendit
unconfigured (no prod keys) — **payouts/disbursements are hard-wired to Xendit for every tenant
regardless of collection gateway**, so no organizer can be paid out until real Xendit keys land.

**Two-TLD split (session-003):** `eventopia.co.id` = public **marketing landing only** (apex + `www` →
the same `web-public` :38100 instance, via the `MARKETING_HOST` middleware guard). `eventopia.my` = the
**app** (`app.` console, `api.`, `<org>.` tenant pages, `checkin.`); its apex + `www` **301 →
eventopia.co.id**. Separate LE cert `eventopia.co.id` (DNS-01, same `.my` CF token). Isolated vhost
`eventopia-coid.conf` on proxy.

## Open follow-ups

**Production + dev (session-007):**
- **Register eventopia with `miaw-route`** (new `apps` + `routes` rows — see session-007 for exact
  values) — eventopia's own Meta webhook verify-handshake was removed upstream; inbound WhatsApp is
  non-functional until this is done. User will register via the miaw-route dashboard.
- Confirm which `miaw-route` instance (dev's PM2-managed one vs `app`'s systemd one) actually fronts
  production Meta traffic before registering.
- `UPLOADS_BASE_URL`/`PUBLIC_UPLOADS_BASE` unset on both envs (default to unroutable
  `https://uploads.local`) — moot until real object storage replaces the fake stub.

**Production (session-006):**
- **Payouts hard-wired to Xendit** for every tenant regardless of collection gateway — no Xendit prod
  keys exist, so payouts will queue up unfilled. Get real Xendit production credentials before
  organizers expect real disbursements.
- **Object storage is a fake in-memory stub** — no real S3 client implemented anywhere in the code.
  DigitalOcean Spaces credentials are in `.env` (`S3_*`) unused; needs a real `ObjectStorage`
  implementation before uploads (KYC docs, event covers, certificates) persist across restarts.
- Operator console has no `ADMIN_IP_ALLOWLIST` and MFA off — internet-reachable, password-only
  (user's explicit choice; revisit later).
- `apps/api/scripts/bootstrap-operator.ts` (real, non-fixture operator bootstrap) was written and run
  on prod but not committed/pushed — worth a PR if useful going forward.
- Confirm the Meta App's webhook subscription uses the new self-generated `META_WEBHOOK_VERIFY_TOKEN`
  (given to the user out-of-band) — otherwise inbound WhatsApp webhooks fail the verification handshake.

**Production (session-003):**
- Confirm CF SSL mode = **Full (strict)** for the `eventopia.co.id` zone in the dashboard (works today;
  the DNS-scoped token can't read zone settings).
- ~~Prod clone pinned at `a289aaa` with a local-only `proxy.ts` edit~~ — **done (session-004):** both
  clones pulled to `1d7cc57`; local patches stashed, behavior now env-driven from on-disk `.env`. Zero
  source drift.

**Production (session-002):**
- ~~TLS~~ — **done** (LE `*.eventopia.my` wildcard via DNS-01 on proxy; CF token at
  `/etc/letsencrypt/cloudflare-eventopia.ini`; auto-renew). Site live over HTTPS.
- **Fill 16 provider placeholders** in `app:~/eventopia/.env` (Xendit, Meta/WABA, S3 + `NEXT_PUBLIC_UPLOADS_BASE`);
  `NEXT_PUBLIC_UPLOADS_BASE` needs a rebuild, the rest a `pm2 restart`.
- Set `platform_rate_config` (commission/PPN/Pajak-Hiburan/fees) for settlement economics.
- checkin redeploys need re-rsync of `dist` → proxy.

**Dev (session-001):**
- ~~The dev clone runs older local-only patches; `git pull` to converge~~ — **done (session-004):** dev
  pulled `b0b75e6`→`1d7cc57`, local patches stashed, now drift-free on env-driven `main`.
