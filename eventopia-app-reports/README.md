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
- **Env:** `dev` with a WA Graph stub (`eventopia-wa-stub`, dev-only PM2 process) and
  fake AI, but **real DOKU/Midtrans/Xendit sandbox credentials** configured (not payment
  doubles), seeded org `kopikita-e2e`. TLS via LE cert `eventopia-dev` (HTTP-01,
  multi-SAN). **79 migrations applied (session-020). Code at `507c15c` (session-020) —
  ahead of prod, which is still on `0bc4d61` pending the Xendit webhook fix deploy.**
  `PUBLIC_API_BASE_URL=https://api.dev.eventopia.my` set (session-020, required for Xendit
  BYO-keys webhook auto-registration).

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
| [008](session-008-2026-07-10.md) | 2026-07-10 | **Register eventopia's WABA with `miaw-route`** (prod) | Found the WABA subscribed to **no** Meta app (dedicated app's webhook was a dead `local.biji.uk` tunnel); fixed by reusing the shared **BIJI Dev** app instead of registering a new dedicated one — `.env` `META_APP_ID`/`META_APP_SECRET` corrected, WABA subscribed to BIJI Dev via Graph API, `routes` row added in `miaw_route`; hit + fixed a PM2 `ecosystem.config.cjs` env-reload gotcha; verified end-to-end with signed synthetic webhooks, including after a concurrent session's redeploy (`3f2c631`) |
| [009](session-009-2026-07-10.md) | 2026-07-10 | Pull `main` (**Tier 0-2 gap remediation: auth, S3 storage, payments, full observability**) to **prod** | `3f2c631`→`34a5385` (40 commits, largest pull to date); **+3 migrations** (72→75, unified `account` identity + RLS); real S3 object storage adapter live (existing DO Spaces creds now used); GlitchTip+OpenObserve+OpenPanel+GA4 provisioned from scratch (new GlitchTip org, OpenObserve service account, 3 OpenPanel projects); hit + fixed a GlitchTip DSN hex-vs-UUID format bug (required refetching + rebuilding all 4 frontends), a `drizzle-kit migrate` silent-failure gotcha (fixed via `node --env-file`), and a `bun`-not-on-PATH build gotcha; Resend enabled then reverted to `stub` after test-send revealed the sender domain isn't verified (pending user input); OpenObserve app-side shipping still not landing (Bun compatibility suspected) — all 5 surfaces green, PM2 stable throughout |
| [010](session-010-2026-07-10.md) | 2026-07-10 | **Live production smoke test** — first-ever real organizer journey (email OTP → event → FREE order → PAID) | Prod `account`/`event`/`orders` were all 0 rows pre-session; email-OTP signup (real browser UI) → 5-step event wizard → publish → free order via direct API (buyer WA-checkout avoided — see findings) → `PAID` in ~2s → ticket `ISSUED`; all test data deleted, DB/Redis back to 0-row baseline. **Found:** OpenPanel analytics 100% broken on all 3 frontends (wrong endpoint, 0 events ever since session-009); buyer checkout is WhatsApp-only with no email alternative (always sends a real WA message); e-ticket email delivery status stuck `ENQUEUED` (unconfirmed send); email-signup orgs stuck with placeholder name "Organizer Baru" (no rename endpoint); public page share/copy-link points at a non-resolving `.co.id` host |
| [011](session-011-2026-07-10.md) | 2026-07-10 | Pull `main` (**Bun observability fix, Register Now CTA, WCAG contrast**) to prod | prod `34a5385`→`721de4a` (12 commits); no new migrations (75); rebuilt api/workers/web-public/console; added missing `NEXT_PUBLIC_CONSOLE_BASE` env var before build (would've baked `localhost` into the new CTA); **new finding:** OTel "duplicate registration" error on api+workers boot (non-fatal, 0 GlitchTip issues) and **OpenObserve log shipping confirmed still broken** post-fix (live before/after test, session-009's fix didn't resolve it); all surfaces green |
| [012](session-012-2026-07-10.md) | 2026-07-10 | Pull `main` (**email organizer registration**) to prod | prod `721de4a`→`00d7d27` (5 commits, console-only, no API/DB changes); rebuilt+restarted `eventopia-console` only (`0.4.1`→`0.4.2`); closes session-010 Finding 4 — new email signups can now set an org name at registration (existing "Organizer Baru" orgs still have no rename path); new copy strings confirmed baked into deployed bundle; 0 new GlitchTip issues |
| [013](session-013-2026-07-10.md) | 2026-07-10 | **Move operator console** `operator.eventopia.my` → `admin.eventopia.co.id` (prod) + reset forgotten `SUPER_ADMIN` password | New DNS A record + expanded `eventopia.co.id` LE cert (3rd SAN) + new nginx vhost on `proxy`; old `operator.eventopia.my` vhost removed entirely (no redirect, unused); `CORS_ORIGINS` updated on `app` (new origin doesn't match the `*.eventopia.my` tenant-pattern CORS rule); hit + fixed the same PM2 `ecosystem.config.cjs` env-reload gotcha as session-008; ran concurrently with session-012's console-only pull with no overlap; new companion script `reset-operator-password.ts` (reuses app's own hashing) used to reset `hi@eventopia.my`'s forgotten password, verified live login `200`; all checks green |
| [014](session-014-2026-07-10.md) | 2026-07-10 | Pull `main` (**smoke-test fixes A–E**) to prod + fix nginx drift from session-013 | prod `00d7d27`→`38b3b3c` (7 commits, all 6 apps); closes every session-010 finding: OpenPanel `apiUrl` (needed 2 new env vars + admin's distinct client-id override), buyer email-OTP checkout, e-ticket email status SENT/FAILED, share-link host fix, **and** fully closes org-rename (new `PATCH /v1/auth/org` for existing "Organizer Baru" orgs); also found+fixed session-013's nginx `sites-enabled`/`sites-available` drift and closed its flagged OpenPanel-CORS follow-up for `admin.eventopia.co.id` — briefly added a redirect for the retired `operator.eventopia.my` before finding session-013's explicit "no redirect" decision and reverting it; all surfaces green, 0 new GlitchTip issues |
| [015](session-015-2026-07-10.md) | 2026-07-10 | **Re-verify smoke-test fixes A–E with a real order** — closes session-014's "not exercised against a real order" gap | Fresh live rerun of session-010's smoke test on prod (`38b3b3c`, unchanged): all 5 findings confirmed fixed — OpenPanel events now land (0→19 in ClickHouse), buyer checkout completed via the new email-OTP UI path (zero WhatsApp involvement), e-ticket `email_delivery_status` flipped to `SENT` immediately (was stuck `ENQUEUED`), org name settable at signup **and** renameable after the fact, share-link now resolves on `.my`; found pre-existing non-test-looking data (4 accounts/events, real event names) predating this session — left untouched, flagged for the user to confirm; all test data created this session deleted, DB back to pre-session baseline |
| [016](session-016-2026-07-10.md) | 2026-07-10 | Pull `main` (**DOKU hardening, buyer email-link/reverse-WA verify, Xendit BYO-keys**) to prod | prod `38b3b3c`→`7b49712` (48 commits, largest since session-009); **+2 migrations** (75→77 — widened `organizer_payment_credential` provider CHECK to add `xendit`, new `organizer_account.xendit_direct_approved` column); frozen-`collection_mode` webhook-verification fix closes a latent money-loss bug across all 3 gateways; **first pg_dump backup** (prod now holds real user data); found + fixed a ~2-month-old fossil (`WEB_DATA_SOURCE=api` only lived in PM2's saved env, not `.env`, since session-007); live-tested both new buyer verification methods with real orders — reverse-WhatsApp via a signed synthetic webhook (session-008's technique), email magic-link via the real confirm/complete API — both `PAID`/`ISSUED`; Xendit ships dark (safe, confirmed `PAYMENTS_DEFAULT_GATEWAY=midtrans`); all test data cleaned up, all surfaces green |
| [017](session-017-2026-07-13.md) | 2026-07-13 | Pull `main` (**public ticketing flow redesign, self-service payments, admin/console UX overhaul**) to prod | prod `7b49712`→`1b1cfd9` (84 commits, largest pull to date); **+1 migration** (77→78 — additive `organizer_account.last_login_at`); guest checkout (no account) + self-service organizer Payment Settings (replaces the operator-gated activation queue) + restyled e-ticket/QR + console/admin UX overhaul with full admin i18n; live-tested guest checkout end-to-end via the real UI — confirmed via reverse-WhatsApp signed synthetic webhook — `PAID`/`ISSUED`; **new finding:** pre-existing `operator_audit_log` hash-chain break at seq 56 (2026-07-10, unrelated to this pull, unresolved); cleanup caught a new gotcha (base `account` row has no FK from event/organizer_account, only reachable via a Redis `membership:acc:*` key); all test data cleaned up (verified against session-016's exact row-count baseline), all surfaces green |
| [018](session-018-2026-07-13.md) | 2026-07-13 | Pull `main` to **dev** (192 commits, catch-up to prod parity) + **real Midtrans sandbox payment test** | dev `3f2c631`→`1b1cfd9` (192 commits, dev's largest gap ever — last touched session-007); **+6 migrations** (72→78, incl. new global `account` table + RLS); also rebuilt+redeployed `checkin` (unlike prod, dev's snapshot wasn't current) and restarted the dev-only `wa-stub` process; patched a missing `NEXT_PUBLIC_CONSOLE_BASE` pre-emptively (the exact session-011 gotcha); **found + worked around a real product gap**: the self-service Midtrans Connect form hardcodes `environment: 'production'` with no sandbox toggle, causing a false 401 on valid sandbox keys — traced to the config resolver, fixed via a direct DB patch; completed a **genuine Midtrans sandbox payment** through Midtrans's own hosted simulator (simulator.sandbox.midtrans.com, BCA VA) — first payment-gateway test in this workspace verified against the real gateway rather than a synthetic webhook — order `PAID`, ticket `ISSUED` via 2 real inbound Midtrans webhooks; all test data cleaned up (13 PG rows + 8 Redis keys, zero residue), all surfaces green |
| [019](session-019-2026-07-14.md) | 2026-07-14 | Pull `main` (**admin ticket/order tracking page + search PII fix**) to **prod + dev** | `1b1cfd9`→`0bc4d61` (3 commits, no migrations/env/deps); new operator-only `/admin/orders` list+detail (troubleshooting, composed timeline); closes a PII leak in `/admin/search` (order/ticket results now gated behind `Order`-read, matching the dedicated endpoints); live-verified on both envs with a real free-ticket order + two temp operator roles (`SUPPORT_OPS` sees it, `COMPLIANCE_OPS` gets 403/empty-search), all test data cleaned up zero-residue; **found 2 new pre-existing prod issues (documented only, not fixed)**: self-service "platform" collection is hard-wired to Xendit ignoring `PAYMENTS_DEFAULT_GATEWAY`, already breaking a real event's checkout (4 `EXPIRED` orders); separately, prod's real Midtrans merchant account has zero payment channels activated — as of today **no gateway can process a real prod payment** |
| [020](session-020-2026-07-14.md) | 2026-07-14 | Pull `main` (**Xendit webhook tenant-resolution fix — money-in/no-ticket**) to **dev** | `0bc4d61`→`507c15c` (35 commits); **+1 migration** (78→79, additive `orders(created_at,id)` index); per-organizer Xendit webhook URL + auto-registration + `payment-reconcile` worker + placeholder guard + VA/cross-tenant fixes, plus a rider admin orders-readability pass, an order-detail tenant-scope fix, and new Terms/Privacy/Refund legal pages; added missing `PUBLIC_API_BASE_URL` env var; rebuilt api/console/admin/web-public (hit + fixed the documented session-009 `tsc` OOM), all 5 procs restarted clean; **isolated DIRECT-Xendit smoke test** (reused platform sandbox key as a stand-in org key, safely isolated): auto-registration confirmed live against real Xendit sandbox API, but the actual webhook 401'd on a stale sandbox dashboard token — the new **`payment-reconcile` worker self-healed it for real** (`RECOVERED` a captured-but-unnotified payment, order `PAID`, ticket `ISSUED`), all test data + temp credentials cleaned up zero-residue; **prod deploy of this same fix intentionally deferred** (dev-first per user instruction) — prod needs its own extra prerequisites (remove placeholder keys, add `PUBLIC_API_BASE_URL`, rotate leaked credentials) before it can go out |
| [021](session-021-2026-07-14.md) | 2026-07-14 | **Planning only** — production hardening + 20,000-ticket load-test & scaling plan | No code/config/infra changed. Analyzed current prod topology (`app`/`db`/`proxy` hardware, PM2 fleet, Postgres/PgBouncer state, existing k6/order-storm load-test harness) and confirmed scope with user: one large single event, 20k tickets over a sustained sale window + event-day check-in burst, ~1 month timeline, payment-gateway routing bugs (session-019/020) out of scope, hybrid staging-then-guarded-prod-rehearsal testing, reuse-existing-capacity scaling. Landed on a **dual-node architecture**: clone `eventopia-api`/`eventopia-workers` onto the underused `db` box (12 cores/48GB, ~2GB used) alongside the existing `app`-box node, load-balanced by `proxy` (`least_conn` + passive health checks), both pointed at one unreplicated Postgres/Redis instance. 5-phase plan (staging build → hardening incl. PgBouncer + BullMQ concurrency + mandatory resource isolation on the `db`-side node → staging load test → guarded prod rehearsal w/ kill-node failover test → runbook + scale-decision point). Phase 0 is the next actionable step, pending user review of this plan. |
| [022](session-022-2026-07-14.md) | 2026-07-14 | Retroactive doc (undocumented `507c15c` prod deploy found already live) + **payment activation ladder** (`affc654`) to prod | Found prod already on `507c15c` (session-020's Xendit webhook fix), fully deployed at 10:36-10:47 that morning but never documented — retroactively recorded. Deployed `507c15c`→`affc654` (35 commits, +3 migrations 79→82): `PAYMENTS_DEFAULT_GATEWAY` fix (closes session-019 Finding 1) + new payment activation ladder (KYC/MoU + operator DIRECT approval); `admin` rebuilt, `api`/`workers`/`operator` restarted, all surfaces green. `org_03f297927f184c0d` grandfathered correctly by the migration but hit a new KYC gate (never formally submitted pre-ladder) — resolved via the real audited operator flow with placeholder bank info (owner's instruction, real info pending). **Found a platform-wide blocker:** `canUseDirect`'s `gatewayAvailable` check gates ALL Xendit-DIRECT organizers on the *platform's* Xendit credentials (still the deferred Step-1 placeholder), not the organizer's own — no Xendit-DIRECT org, including this one, can collect a real payment until Step 1 lands. Documented only, per user decision. Also: an accidental `.env` grep leaked a live WhatsApp token into the transcript (flagged, rotation optional). |
| [023](session-023-2026-07-15.md) | 2026-07-15 | Deploy `f5dc400` (**custom landing pages + custom domains**) to prod; build 2 custom event pages; **fix landing-page UI** | `affc654`→`f5dc400` (32 commits, +2 migrations 82→84 additive: `event_page` table + RLS, `domain` cert cols): **custom event landing pages** (block editor + `data-lp` renderer), **custom domains** (Cloudflare for SaaS), and the **DIRECT-collection decouple fix** (`b21cfe8`) — which **refutes session-022's blocker**: `org_03f297927f184c0d`'s `POST /v1/payments` now returns 201 with a real Xendit-DIRECT QRIS intent, not 503. Added `CF_API_TOKEN`/`CF_ZONE_ID`/`DOMAINS_CNAME_TARGET`; rebuilt/restarted api/console/web-public. **Custom domains blocked, not live:** Cloudflare setup done (DNS + Fallback Origin `active`) and TXT ownership verifies, but cert issuance fails — `custom_origin_sni` (SNI Rewrite) is **Cloudflare Enterprise-only** and the zone is Free plan; plan/billing gate, not a code bug (documented `f104ea1`). Built **two custom landing pages** by direct `event_page` SQL (validated against the real contract first, ISR-purged): a test ocarina page + the **real Festival Mbois 11 / Malang Menyala** page (`epg_9370435c…`, 17 blocks — showcase style, real content + honest placeholders, real tickets untouched, the festival's own **glowing-orb** hero artwork self-hosted). Driving it live surfaced **3 shared-feature UI bugs**, fixed + committed (`1749989`, pushed, prod git reconciled): scroll-reveal `opacity:0` left viewport-taller blocks (tickets/map) **permanently invisible on Chromium** → made transform-only; 11px eyebrow/label text bumped; replaced the ugly CSS orb with a generic hero **`sideImage`** field. Gotcha: `PageDoc` is parsed in `apps/api` (Bun in-memory) so a new contracts field needs an **api restart**; console-editor publishes and direct-DB writes **clobber each other** (user chose DB as source of truth, pausing console edits). |
| [024](session-024-2026-07-16.md) | 2026-07-16 | Deploy `70e4aec` (**AI page-gen, Audience CRM, ticket capacity, custom-domains free-tier fix**, 94 commits — largest pull yet) to prod; new Cloudflare screenshot Worker; hero-artwork migration; **custom domains verified LIVE end-to-end** | `1749989`→`70e4aec`, **+1 migration** (84→85, additive `event.max_tickets` + nullable `ticket_type.quota`); AI landing-page generation enabled live (Claude Opus 4.8, **OAuth** token from the operator's Keychain — no refresh loop, user's explicit choice over the doc's API-key recommendation); built + deployed a **new standalone Cloudflare Browser Rendering Worker** (`infra/cf-screenshot-worker/`, outside the pnpm workspace) backing the AI page-gen URL-screenshot feature, verified live end-to-end; **custom-domains free-tier fix shipped AND proven live** — user flipped the `eventopia.my` zone Full-strict→Full, a test domain (`custom-test.biji.uk`) walked the full `PENDING→VERIFIED→PROVISIONING→LIVE` path against the real Cloudflare API and served real HTTPS traffic (`200`, not `526`) — **refutes session-023's Enterprise-SNI blocker**, released/cleaned up after; hero-artwork migration done for the real Mbois page via direct S3 upload + DB update (no organizer console credentials available), ocarina page had nothing to migrate; console/web-public rebuilt, api/workers restarted, re-checked stable ~50min later, 0 new errors both passes. **Feature-level smoke test** (a short-lived token minted with the real prod signing key, scoped to the test org, user-approved): ticket-cap enforcement, ticket-visibility toggle, and the sliding-banner block all **proven live** with real API calls (real `409` on cap overflow, real image render) then fully cleaned up; found a real gap — Audience CRM shows 0 contacts for the org's 4 pre-existing PAID orders (no backfill for orders older than the feature). **Self-caught incident:** an `.env` line-range dump briefly printed the DO Spaces access/secret key into the transcript — flagged, rotation deferred by user request. |

## Production footprint (`app` / eventopia.my + eventopia.co.id)

CF (orange, **`eventopia.my` zone now Full, not strict** — flipped session-024 to unblock custom
domains) → `proxy` nginx → `app` `10.0.0.5:380xx` (PM2 under `devops`, Next bound
`10.0.0.5`). DB+Redis on `db` `10.0.0.1` (PG16, role `eventopia` w/ `BYPASSRLS`, **Redis db6**). Bun +
pgvector installed as prereqs. No seed. checkin static served from proxy. **85 migrations applied
(session-024). Code at `70e4aec` (session-024, 94-commit pull — largest yet).**

**AI landing-page generation (session-024):** `AI_PROVIDER=anthropic`, Claude Opus 4.8, enabled live.
Auth is **OAuth** (`ANTHROPIC_AUTH_TOKEN`, the operator's Claude Max 20x Keychain token) — **no refresh
loop wired in eventopia's code**, so it will start 401ing once the token expires (~8h typical) until
someone manually re-extracts + redeploys it. URL-source screenshots go through a **new standalone
Cloudflare Browser Rendering Worker** (`infra/cf-screenshot-worker/` in the repo, outside the pnpm
workspace — deploys independently to Cloudflare, not to `app`/`dev`), `https://eventopia-page-screenshot.biji.workers.dev`,
on the Workers Free tier's Browser Rendering allotment.

**Observability (session-009):** GlitchTip org `eventopia` (projects `eventopia-backend`/`-web`/`-checkin`,
`errors.biji.uk`), OpenObserve service account `eventopia-ingest@biji.uk` + stream `eventopia_api`
(`observe.biji.uk`, app-side shipping not yet confirmed landing — see README follow-ups), OpenPanel
projects `eventopia-console`/`-operator`/`-checkin` (org `biji`, `analytics.biji.uk`) — `apiUrl` +
per-project CORS fixed session-014, previously 100% inert since provisioning, GA4
`G-8YBGDDMSQ3` (web-public only). Real S3 object storage (DigitalOcean Spaces, bucket `eventopia`,
`sgp1`) now live — public cover-image reads still broken pending a code fix for per-object ACLs (see
follow-ups; accepted as low-risk for now — object keys are unguessable UUIDs). Email (Resend) **live**
(`EMAIL_PROVIDER=resend`, `eventopia.my` verified) for e-ticket QR emails + OTP login.

**Operator console (session-006, moved session-013):** `admin.eventopia.co.id` → `app` `10.0.0.5:38400`
(PM2 `eventopia-operator`, admin standalone), on the `eventopia.co.id` LE cert (expanded to 3 SANs).
Previously `operator.eventopia.my` (retired, no redirect — nginx vhost removed). CORS for this origin
is an explicit `CORS_ORIGINS` entry on `app` (doesn't match the `*.eventopia.my` tenant-pattern CORS
rule other first-party frontends rely on). MFA off, no IP allowlist — internet-reachable, password-only
login. First real account: `hi@eventopia.my` (`SUPER_ADMIN`).

**Payments (session-006, hardened session-016, self-service since session-017, activation ladder
session-022):** DOKU + Midtrans live (`PAYMENTS_DEFAULT_GATEWAY=midtrans`, real credentials but
**Midtrans has zero payment channels activated on the real merchant** — session-019 Finding 2, still
open, MAP-dashboard gap not code); platform Xendit **still has no `XENDIT_API_KEY`/`XENDIT_WEBHOOK_TOKEN`
at all** (not even a placeholder — deploy-doc "Step 1", still pending real credentials from the owner).
Session-022 shipped a **4-rung payment activation ladder**
(`BLOCKED → FREE_ONLY → PAID_PLATFORM (KYC VERIFIED + MoU SIGNED) → DIRECT (+ per-provider operator
approval)`, `packages/payments/src/capability.ts`) and fixed the session-019 hard-coded-Xendit bug
(platform-mode collection now stores `NULL` and resolves `PAYMENTS_DEFAULT_GATEWAY` live). **Known
gap (session-022, undecided):** DIRECT collection's `canUseDirect` also requires the *platform's*
credentials for that gateway to be configured (`gatewayAvailable`), even though DIRECT never uses
them — so with the platform Xendit key still absent, **no Xendit-DIRECT organizer can currently
collect a real payment**, including the one BYO-keys pilot org (`org_03f297927f184c0d`). Payouts are
still hard-wired to Xendit for every tenant regardless of collection gateway (session-006) — no real
Xendit keys, no payouts yet either. Session-016 landed a frozen-`collection_mode` webhook-verification
fix across all three gateways, closing a latent money-loss bug. **Session-017** replaced the old
operator-gated payment-activation queue with a **self-service organizer Payment Settings page**.

**Buyer checkout verification (session-016):** alongside the existing email-OTP method (session-014),
buyers can now verify via **reverse-WhatsApp** (send a code to the Eventopia number, no template needed)
or **email magic-link** (click a one-time link, can be on another device) — both live-tested with real
orders, `PAID`/`ISSUED`.

**Two-TLD split (session-003):** `eventopia.co.id` = public **marketing landing only** (apex + `www` →
the same `web-public` :38100 instance, via the `MARKETING_HOST` middleware guard). `eventopia.my` = the
**app** (`app.` console, `api.`, `<org>.` tenant pages, `checkin.`); its apex + `www` **301 →
eventopia.co.id**. Separate LE cert `eventopia.co.id` (DNS-01, same `.my` CF token). Isolated vhost
`eventopia-coid.conf` on proxy.

## Open follow-ups

**New (session-024):**
- ~~Custom-domains live test unfinished~~ — **done, same session**: user published the DNS records, a
  test domain (`custom-test.biji.uk`, org `org_03f297927f184c0d`) walked the real Cloudflare API through
  `PENDING→VERIFIED→PROVISIONING→LIVE` and served real HTTPS (`200`, not `526`) — **refutes session-023's
  Enterprise-SNI blocker**. Test hostname + DB row released/deleted after. The two now-unneeded DNS
  records on `biji.uk` can be removed whenever convenient.
- **Prod's git clone is 1 commit behind `origin/main`** (`70e4aec` vs. `bbb41d5`, the `cf-screenshot-worker`
  files the user committed directly) — zero functional drift (that path is outside the pnpm workspace,
  not deployed via the app server), a plain `git pull` next session closes it.
- **`ANTHROPIC_AUTH_TOKEN` has no refresh loop** — will need manual re-extraction from the operator's
  Keychain + `.env` update + `eventopia-api` restart once the current token expires.
- **DO Spaces `S3_ACCESS_KEY`/`S3_SECRET_KEY` were briefly exposed in a session-024 transcript** (a
  `.env` line-range dump, self-caught, no evidence of misuse) — user deferred rotation to a later
  session, noted here as a reminder.
- **Audience CRM shows nothing for orders that predate the feature** — `org_03f297927f184c0d` has 4 real
  PAID orders (2026-07-14/15) but 0 `contacts` rows; `upsertContact` only runs on new buyer checkouts, no
  backfill exists for historical orders. Confirmed live session-024 (`GET /v1/crm/contacts` → empty despite
  real orders). Worth a backfill script if the directory needs pre-launch customers, else accept as-is.
- Ticket-cap enforcement, ticket-visibility toggle, and the sliding-banner block were all **click-tested
  live** session-024 (a minted test token against a throwaway event, real `409` on cap overflow, real
  image render) — see session-024 Part 5b. AI-gen was skipped intentionally (real Opus 4.8 cost) — route
  confirmed wired, generation itself not yet exercised.
- `/lp/hero-orb-mbois.png` stopgap + its passthrough branch in `apps/web-public/proxy.ts` are no longer
  referenced by any `event_page` (confirmed) but weren't retired — harmless to leave, a code change to
  finish if anyone wants to close it out.
- No per-organizer rate limit on `POST /v1/events/{id}/page/generate` yet — the button is visible to
  every organizer now that the flag is on; watch the Anthropic bill (Opus 4.8 is the premium tier).

**New (session-022):**
- **No Xendit-DIRECT organizer can collect a real payment on prod** — `canUseDirect`'s
  `gatewayAvailable[gateway]` check (`packages/payments/src/capability.ts`) gates DIRECT
  collection on the *platform's* credentials for that gateway, which DIRECT doesn't otherwise
  use. Blocked until platform Xendit keys land (deploy-doc Step 1) or the gate is reconsidered.
  Documented only this session per user decision — see session-022 for the full trace.
- `org_03f297927f184c0d`'s bank details in `organizer_payout_profile` are a **placeholder**
  (`PENDING-REAL-BANK-INFO`) — needs real bank info before any payout can be disbursed.
- `hi@eventopia.my`'s operator password was reset session-022 (forgotten/rotated) — new
  credential given to the user out-of-band, not in any report file.
- Consider rotating `META_GRAPH_API_ACCESS_TOKEN` — briefly exposed in the session-022
  transcript via a redaction-regex bug on an `.env` grep. No prod/payment impact.

**Production hardening / 20,000-ticket-sale readiness (session-021, planning only):**
- Phase 0 (isolated staging: `eventopia-api`/`eventopia-workers` cloned onto `db` alongside the
  existing `app`-box node, load-balanced by `proxy`) is the next actionable step — pending user
  review of the plan and go-ahead to start. See session-021 for the full 5-phase plan
  (staging → hardening incl. PgBouncer + BullMQ concurrency + mandatory resource isolation on
  the `db`-side node → staging load test → guarded prod rehearsal w/ kill-node failover test →
  runbook + scale-decision point). Explicitly does not include the payment-gateway bugs below —
  tracked separately.

**Production (session-019):**
- ~~Self-service "platform" collection is hard-wired to Xendit~~ — **done (session-022):** the
  `PAYMENTS_DEFAULT_GATEWAY` fix shipped in `affc654` makes platform-mode collection store
  `NULL` and resolve the configured default live, per request.
- **Prod's real Midtrans merchant account (`M073614114`) has zero payment channels activated** — confirmed via direct API calls with the real prod Server Key: VA/QRIS → `402 Payment channel is not activated`, GoPay → `404`. This is a Midtrans-dashboard-side (MAP portal) config gap, not code. **Still open (session-022):** combined with the new DIRECT-Xendit gating gap above, no gateway can process a real payment on prod as of session-022 either.

**Dev (session-018):**
- Self-service Midtrans (and likely Xendit/DOKU) BYO-keys Connect form has no
  sandbox/production toggle (`apps/console/components/payments/gateway-connect-form.tsx`
  hardcodes `environment: 'production'`) — by design for real organizers, but means
  testing a BYO gateway connection against sandbox needs a manual `organizer_payment_
  credential.environment` DB patch. Worth a deliberate decision (accept as permanent, or
  add a hidden/dev-only toggle).

**Production (session-017):**
- **`operator_audit_log` hash-chain break at seq 56** (`action=audit.export`, 2026-07-10 17:27:30) —
  found via the `operator-audit-verify` cron logging `CHAIN BREAK ... row_hash_mismatch` every 10
  minutes; predates session-017 by 3 days, unrelated to that session's pull. Root cause not
  investigated — an unresolved break undermines the audit log's tamper-evidence guarantee.
- Public event pages on tenant subdomains 404 on `icon.svg` (missing favicon) — cosmetic, low priority.

**Production (session-016):**
- `WEB_DATA_SOURCE` was undocumented/fossil-only for ~2 months (session-007 to now, living only in PM2's
  saved process env, never in `.env`) — re-added explicitly this session; worth a periodic `diff .env vs
  pm2 env` check in future sessions to catch other drift between the tracked file and what's actually running.

**Production (session-015):**
- Confirm whether the 4 pre-existing accounts/events found at the start of this session (real-looking names: "International Ocarina Festival", "MalangMusic", "Nusantara Music Festival 2026", "JavaHeksa") are organic real signups or leftover test data from another session — not touched, not investigated further.

**Production (session-014):**
- ~~Neither the e-ticket delivery-status fix nor the buyer email-checkout fix has been exercised against a real order yet~~ — **done (session-015)**: both confirmed live via a real order through the actual UI — `email_delivery_status` flipped to `SENT`, checkout completed on the email path with zero WhatsApp involvement.
- Operator console has no IP allowlist / MFA (explicit user choice, carried since session-006) — worth revisiting now that it's freshly re-exposed on a new public domain (session-013).

**Production (session-013):**
- ~~`eventopia-operator`'s OpenPanel project CORS allowlist almost certainly still references the retired `operator.eventopia.my`~~ — **done (session-014)**, updated to `{https://admin.eventopia.co.id}`.

**Production (session-012):**
- ~~Organizer email-signup naming is only half-fixed~~ — **fully done (session-014)**: new `PATCH /v1/auth/org` (owner-only) + console `/settings/profile` lets any organizer rename their org, closing the gap for pre-existing "Organizer Baru" accounts too.

**Production (session-011):**
- OTel "Attempted duplicate registration of API: context" on `eventopia-api`/`eventopia-workers` boot — new, non-fatal (no crash-loop, 0 GlitchTip issues), likely Sentry's own `initOtel` colliding with the app's `tracing.ts` init after this session's Bun auto-instrumentation fix. Needs investigation.
- OpenObserve app-side log shipping **confirmed still broken** — session-009's Bun-incompatibility fix landed but a live before/after test on the `eventopia_api` stream showed zero new docs across 10 minutes of fresh traffic post-restart. The duplicate-registration error above is a plausible cause; fix that first, then re-test.

**Production (session-010):**
- ~~OpenPanel analytics is completely non-functional~~ — **done (session-014), confirmed live (session-015)**: `apiUrl` set on console/admin/checkin; `eventopia-console` ClickHouse events went 0→19 during session-015's live rerun.
- ~~E-ticket email delivery status unconfirmed~~ — **done (session-014), confirmed live (session-015)**: `email_delivery_status` flipped `ENQUEUED`→`SENT` within ~2s of a real order.
- ~~Buyer/attendee checkout has no email-OTP alternative~~ — **done (session-014), confirmed live (session-015)**: completed a real checkout via the email tab, zero WhatsApp involvement.
- ~~No way to set/rename an organizer's display name via email signup~~ — **fully done (session-014), confirmed live (session-015)**: both signup-time naming and post-hoc rename tested end-to-end.
- ~~Public event page share/copy-link builds URLs against `eventopia.co.id`~~ — **done (session-014), confirmed live (session-015)**: share link + canonical URL both resolved on `eventopia.my`.
- Stale dashed-format "Invalid Sentry Dsn" line in `eventopia-workers`' unrotated PM2 log — live env confirmed correct (session-009's fix holds), but worth clearing logs next deploy to avoid re-litigating this.

**Production (session-009):**
- ~~OpenObserve receives nothing from the app~~ — **attempted fix landed, did not resolve (session-011)**:
  the suspected Bun/OTel incompatibility fix shipped but a live before/after test still showed zero new
  docs; see session-011's follow-ups for the current lead (OTel duplicate-registration error). GlitchTip/OpenPanel/GA4 are unaffected.
- **Object storage ACL conflict** — the new S3 adapter sets no per-object ACL, so the bucket's one
  default ACL applies to both public cover images and private KYC/MoU/certificate docs. Public images
  stay broken (no regression — they were never persisted before either) until a code change adds
  prefix-conditional `x-amz-acl` (public prefixes public-read, private prefixes stay private). User's
  call: accepted as low-risk for now (object keys are unguessable UUIDs, no one can enumerate them) —
  harden later, not urgent.
- `ticket_transfer_out`/`ticket_transfer_in` WhatsApp templates need **Meta Business Manager approval**
  before transfer notifications actually send.
- `pnpm db:migrate` fails silently over SSH (spinner swallows the real error) — root cause is
  `DATABASE_URL` not being picked up automatically; use `node --env-file=<path-to-.env> <script using
  drizzle-orm/postgres-js/migrator>` instead of the bare CLI. `bun` also needs
  `export PATH="$HOME/.bun/bin:$PATH"` explicitly for non-interactive SSH build commands.

**Production + dev (session-007):**
- ~~Register eventopia with `miaw-route`~~ — **done (session-008)**, prod only: WABA subscribed to the
  shared **BIJI Dev** app (not a new dedicated `apps` row as originally proposed here — that WABA turned
  out to have zero apps subscribed at all), `routes` row added, verified end-to-end. `app`'s systemd
  instance behind `routes.biji.uk` confirmed as the one fronting production Meta traffic.
- ~~`UPLOADS_BASE_URL`/`PUBLIC_UPLOADS_BASE` unset on both envs~~ — **done (session-009)** on prod, set
  to the real DO Spaces base; dev still unset (dev still runs the fake object-storage sink, moot there).

**Production (session-008):**
- No real WhatsApp message has been sent through the live path yet — only synthetic signed webhooks;
  worth a real inbound test to `wa.me/6285178123275` when convenient.
- eventopia's now-unused dedicated Meta app (`307017735009770`) still has its own dead webhook config
  pointing at `local.biji.uk` — harmless, left alone; candidate for cleanup later.

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
