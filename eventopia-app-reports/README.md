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
  multi-SAN). **98 migrations applied (session-025). Code at `f8515b9b` (session-025) —
  now AHEAD of prod (`70e4aec`, 85 migrations) on both migrations and features** (refund
  requests, ticket groups, organizer landing pages, embed/BRImo groundwork, WA BYO numbers
  all live on dev only). `PUBLIC_API_BASE_URL=https://api.dev.eventopia.my` set
  (session-020). **New `eventopia-wa-gateway` PM2 service** (session-025, `WA_GATEWAY_SOCKET=fake`
  — no real Baileys socket on dev). `NEXT_PUBLIC_WEB_PUBLIC_BASE=https://dev.eventopia.my`
  set (session-025, required or console preview links break). BRImo code present,
  **`BRIMO_SECRET_KEY` now configured** (session-026, BRI's published dev key) — one org,
  `org_3c6828c4cdd245af`, is Xendit-pinned and ready for a Layer 2c test, but BRImo is not yet
  enabled for it in Console → Settings → Payments (org-authenticated action, left for the
  user). **`PAYMENTS_DEFAULT_GATEWAY=xendit`** dev-wide (session-026, explicit user
  instruction — every organizer without its own gateway pin now resolves to the platform
  Xendit sandbox key; `doku` is no longer dev's default). Still on the fake in-memory
  object-storage stub (no `S3_*` set).

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
| [025](session-025-2026-07-21.md) | 2026-07-21 | Pull `main` (**WA BYO numbers, payment ladder, refunds, ticket groups, organizer landing pages, embed/BRImo groundwork**, 349 commits — largest pull yet) to **dev** | `507c15c`→`f8515b9b`; **+19 migrations** (79→98); pre-checked both data-migrations (`0080` KYC/MoU CHECK, `0087` active-phone unique index) against dev's real data before running — both clean; **new `eventopia-wa-gateway` PM2 service** added (`WA_GATEWAY_SOCKET=fake`); built web-public/console/admin sequentially under a capped heap (dev has only 417MB free RAM, 30+ other tenants on the box) — no OOM; rebuilt+rsynced `checkin` (stale since session-023); added `NEXT_PUBLIC_WEB_PUBLIC_BASE` (new required var, avoids baking `localhost` into console preview links); all surfaces green, 0 new errors. **Deliberately deferred:** BRImo left inactive (today's own `docs/launch/brimo-sandbox-validation.md` scoped dev as the last validation step, not the next one), real S3/media-CORS wiring, real Cloudflare custom-domain credentials. **Dev now ahead of prod** on both migrations (98 vs 85) and features. |
| [026](session-026-2026-07-21.md) | 2026-07-21 | Unblock BRImo sandbox testing on **dev** (missing `BRIMO_SECRET_KEY`, gateway pin) | Added `BRIMO_SECRET_KEY` (BRI's own publicly-published dev key, already in the repo's committed docs — not a real secret) + `BRIMO_ENVIRONMENT=dev`; confirmed dev already has a working Xendit sandbox key (prod has none at all); `PAYMENTS_DEFAULT_GATEWAY` flipped `doku`→`xendit`→`doku`→**`xendit`** (3 restarts) — briefly scoped back to `doku` + a single pinned org (`org_3c6828c4cdd245af`, "Festival Mbois 11 - Malang Menyala", already `payment_gateway=xendit`+`xendit_direct_approved=true`, zero DB change needed), then the user explicitly asked to keep `xendit` as dev's platform-wide default after all — final state is `xendit` dev-wide; all restarts `/readyz` green, no migration/rebuild. **Next actionable step:** enable BRImo for that org in Console → Settings → Payments (left for the user), then the phone/embed-page test in `docs/launch/brimo-sandbox-validation.md`. |
| [028](session-028-2026-07-22.md) | 2026-07-22 | Deploy **Google sign-in (better-auth), policy pages, "one WhatsApp number"** (24 commits) to prod | `59985653`→`edbd0ab`; **+2 migrations** (98→100, `ba_*` better-auth tables + RLS deny-all); found + fixed a stale `API_BASE_URL=http://127.0.0.1:38001` on prod that would have broken Google's redirect-uri check outright, added the missing `CONSOLE_BASE_URL`, generated `BETTER_AUTH_SECRET` on-host; console (0.22.0) + web-public (0.16.0) rebuilt, api (0.29.0)/workers restarted, operator untouched; **hit and fixed a real gotcha**: `pm2 restart <name> --update-env` doesn't re-read `ecosystem.config.cjs`, so the first restart silently kept the stale env — caught by a live smoke test, fixed via `pm2 restart ecosystem.config.cjs --only ... --update-env`. Verified end-to-end with a real Playwright click-through to a genuine `accounts.google.com` sign-in page (correct `client_id`/PKCE/`redirect_uri`); WA landing-page CTAs confirmed auto-inheriting the existing `WA_PLATFORM_NUMBER` with zero extra config. All 5 PM2 procs green, 0 unstable restarts. |
| [029](session-029-2026-07-22.md) | 2026-07-22 | 🟢 **Deploy the check-in white-screen fix (LIVE)** + panitia WhatsApp sign-in, payment-method toggles, org-name self-heal, custom-domain embed page (53 commits) to prod | `edbd0ab`→`b63c7200`; **+2 migrations** (100→102, additive `domain.target` + `organizer_account.disabled_payment_methods`); fixed `VITE_TICKET_PUBLIC_KEY` (the session-027 outage — wrong encoding, independently re-derived and confirmed matching), added missing `CHECKIN_BASE_URL` + the undocumented-in-`.env.example` `NEXT_PUBLIC_CHECKIN_URL`; console (0.26.0)/web-public (0.18.0) rebuilt, checkin (0.5.0) rebuilt + redeployed to `proxy` (old broken dist backed up first), api/workers restarted via the ecosystem-file form from the start (no repeat of session-028's gotcha). **Playwright-verified live: `checkin.eventopia.my` renders 0 console errors, full staff sign-in screen** — the 6+-week outage is over on prod. `dev` still needs the same fix (out of scope this session). All PM2 procs green, `↺:1` each. |
| [030](session-030-2026-07-22.md) | 2026-07-22 | ✅ Root-cause: creating a duplicate-name event 500s ("Terjadi kesalahan internal") — **fixed same evening, confirmed live** | **Read-only investigation, nothing changed on either server.** User hit the error creating "Festival Mbois 11 - Concert"; `eventopia-api` logs showed the real cause — a `DrizzleQueryError` unique-violation on `event_organizer_slug_uq` (the organizer already had a same-named `DRAFT` event from 2026-07-17, auto-generated slugs collided), uncaught in `createEventRoute` and uncaught by the global `onError` handler, which has no `23505` case — falls through to the generic 500. **Update (2026-07-23):** a separate coding-agent session fixed this the same evening (`05811823`/`85084060`, citing the identical prod reproduction) — a derived slug now auto-disambiguates (`-2`, `-3`, …), an explicit slug collision 409s as `EVENT_SLUG_TAKEN`, and `onError` maps any remaining `23505` to a clean `409`. Shipped in session-032's deploy (`ac2504e5`), confirmed present in prod's current checkout (`fc32f4f1`) via live `grep`. This session's own `known-issues.md` filing was never committed and didn't survive the clone's fast-forward — no refile needed, the bug is already fixed and its entry already removed by `2125ffed`. |
| [031](session-031-2026-07-22.md) | 2026-07-22 | Root-cause: **BRI-VA/BRImo collection 503s** ("Gerbang pembayaran sedang tidak tersedia") — wrong Xendit VA product, not an organizer gap | Read-only investigation + two harmless diagnostic Xendit API calls. Ruled out the session-029 `disabled_payment_methods` toggle (user's own hypothesis) by data — BRIMO isn't in the org's disabled set and that path 422s, not 503s. Initial read (org's Xendit account not activated for BRI) was **disproven** when the user pushed back with their own dashboard screenshot — replayed the identical VA-creation call with the **platform's own** Xendit key and got the identical `400 BANK_NOT_ACTIVATED_ERROR`. Root cause: the integration calls Xendit's **Fixed VA** API (`/callback_virtual_accounts`) but this business only has BRI activated under the separate **Invoice VA** product (confirmed against Xendit's own docs) — a product/integration mismatch, not an account gap, and not organizer-specific. Dev/sandbox test blocked by an apparent fail2ban lockout on that host from this session's own failed logins. Filed (rewritten) in eventopia repo's `docs/engineering/known-issues.md` (uncommitted), alongside the still-valid missing-error-logging gap. **Superseded by session-032**: a developer-agent session (separately, same day) found the real shape is per-bank, not per-product — BNI mints fine on the organizer's Fixed-VA key while BRI/BCA/MANDIRI/PERMATA don't, so it isn't "Fixed VA is off" after all. |
| [032](session-032-2026-07-23.md) | 2026-07-23 | Deploy **archive/soft-delete + duplicate-slug fix + payment-visibility fix** (34 commits) to prod; found + fixed a **migration-journal timestamp bug** live; re-verified BRI VA | `b63c7200`→`ac2504e5`; migration 0102 silently no-op'd (drizzle-orm's migrator uses a single `MAX(created_at)` cursor, and hand-written 0100/0101's synthetic timestamps exceed 0102's real one) — root-caused by reading the migrator's own source, fixed via manual DDL + tracking-row insert, independently verified via `information_schema`; console (0.27.0) rebuilt, api restarted, workers untouched (nothing on its path changed); 0 console errors on `app.`/`www.`/`checkin.`. **BRI VA re-test:** platform Xendit account now mints BRI/BNI/MANDIRI/PERMATA (user activated channels directly) — only BCA left; **organizer's own account (EPOCHSTREAM) unchanged and worse than documented** — only BNI mints, BRI/BCA/MANDIRI/PERMATA all still `BANK_NOT_ACTIVATED_ERROR` — so the originally-reported BRImo outage is **still live**, unaffected by the platform-side fix. `known-issues.md` rewritten + **committed and pushed to `origin/main`** (`7aa5ec1`) from `app`'s own checkout, avoiding a shared local clone found mid-session to be on a concurrent developer-agent's WIP branch (`feat/brimo-per-org-secret-key`). 3 DB backups taken across the session. |
| [033](session-033-2026-07-23.md) | 2026-07-23 | Deploy **per-method payment gateway status + BRImo per-org keys** (21 commits) to prod; found + fixed a **second live migration-skip incident**; closed the migrator landmine at the repo level | `7aa5ec1c`→`fc32f4f1`; migration 0103 silently skipped — this time because session-032's own manual fix for 0102 used `Date.now()` for its tracking-row `created_at`, inflating the cursor past 0103's own real (already-generated) timestamp; read the actual installed drizzle-orm source to confirm the exact mechanism (cursor fetched **once** per `migrate()` call, so a single fresh replay is safe — the danger is separate invocations over time); fixed live via backed-up DDL + tracking-row insert, independently verified. **Fixed the repo root cause, not just prod**: bumped `_journal.json`'s `when` for 0102 (session-032's own documented fix, never implemented) and audited the **entire 106-entry journal**, finding a second dormant instance (`0019`–`0027`, 9 migrations, no live impact — already applied everywhere, confirmed via `information_schema`) — renumbered both, verified via `pnpm db:check` + a monotonicity check. Documented the precise mechanism + a safer recovery recipe (use the skipped migration's own `when`, not `Date.now()`) in `MIGRATIONS.md`; removed the resolved `known-issues.md` entry per its own convention (also fixed an unrelated merge artifact there). Console (0.29.0) rebuilt, api restarted; 0 console errors on `app.`/`checkin.`; live traffic already hitting the new route successfully. **3 commits local-only, not yet pushed — awaiting user decision.** |
| [027](session-027-2026-07-21.md) | 2026-07-21 | 🔴 **Root-cause: `checkin.eventopia.my` white-screens on boot** (`invalid base64url character`) — **prod AND dev both down** | **Read-only investigation, nothing changed.** User reported an uncaught `invalid base64url character` on prod check-in and asked whether it was "not yet built" — it's the opposite: it *was* built, with a malformed value baked in. `VITE_TICKET_PUBLIC_KEY` on both hosts is the **standard-base64 SPKI DER** value copy-pasted from the adjacent `EVENTOPIA_ED25519_PUBLIC_KEY` (`MCowBQYDK2VwAyEA…=`), but `apps/checkin/src/config.ts:32` decodes it as **base64url of the raw 32 bytes** — `/` and `=` aren't in the base64url alphabet, so `packages/qr/src/encoding.ts:57` throws at **module top level**: the ES module never finishes evaluating, React never mounts, `#root` stays empty, and **GlitchTip sees nothing** (Sentry.init is in the same dead module graph). Reproduced live on prod with Playwright (`index-BqzWQyxm.js`, 2026-07-10); the hash in the user's report (`index-DJKbUFQ1.js`) turned out to be **dev's** bundle, built today by session-025 — both environments broken independently, same cause. **Broken since at least 2026-06-24**: both archived prod dists on `proxy` contain the same bad value, so **there is no known-good build to roll back to** — forward-fix only. Decoded the value to prove both defects (44-byte DER-wrapped, not raw 32; standard base64, not base64url) and computed the correct values against each host's own signing key: prod `JRLeS3Gqgqa6Hb_Qfg9aYxgbcV8MpIaf3kxNje4DNds`, dev `SXKtc6W8-wRzdT0JkxuRRJGUag_mDzzCR0Xeyhw5f54`. Bounded the security impact by tracing the runtime override (`EventGateSelector.tsx:58` → `savePublicKey` → `resolvePublicKey`): a device that can scan has already overwritten the build-time key, so the fail-soft-to-DEV-key path — whose *private* half is committed in `packages/keys` — isn't reachable for scanning. **Why it survived 6 weeks:** deploy verification was `curl` status only (sessions 009/014 both recorded `checkin.eventopia.my | 200` — a static SPA 200s even when its JS throws), nothing validates the value at build time, and check-in is only exercised at a real event. **Fix proven live, not inferred:** a controlled A/B against the production bundle (SW blocked, `/assets/index-*.js` intercepted, that **one string** swapped in-flight and nothing else) took the page from `invalid base64url character` + empty `#root` to **0 console errors and a fully rendered staff login screen** — so the env value is the only defect, with no second bug behind it; WebCrypto `importKey('spki')→exportKey('raw')` further confirmed both computed values are **byte-identical** to what the API ships as `bundle.publicKey` (no split-brain after the fix). Also measured in-browser: `window.__SENTRY__` undefined (**telemetry blind spot proven, not assumed**) while the SW registers fine (separate classic script). **⚠️ New operational finding:** the Workbox precache holds the stale `index.html` **and** the crashing bundle and serves them ahead of the network (it silently defeated the first interception attempt) — so after the fix deploys, an installed device **white-screens once more on the first load** and only boots on the **second**; door staff must be told "if it's still blank, close and reopen once". Fix handed to a coding agent: correct the env + rebuild/redeploy, plus repo hardening (shared `parseEd25519PublicKey` normalizer accepting all 3 encodings, **build-time guard that fails the build instead of the browser**, a third `VITE_TICKET_PUBLIC_KEY=` line emitted by `generate-keypair.ts` to kill the copy-paste trap at source, tests, browser-render deploy check). |
| [034](session-034-2026-07-21.md) | 2026-07-21 (written up 2026-07-23) | Deploy `70e4aec→59985653` (196 commits, BRImo Stage 1 groundwork) to prod + activate **platform Xendit/DOKU production credentials** (first-ever) + real end-to-end payment smoke test | **+13 migrations** (85→98); pre-checked `0087`'s unique index against real data (zero rows, no conflict) and `0090`'s backfill (RLS-blocked, harmless) before running; web-public (0.15.0)/console (0.20.0) rebuilt, api/workers/web-public/console restarted clean, operator/wa-gateway untouched (zero diff / deliberately not started — no real WA pairing tested anywhere yet). **Added prod's first-ever Xendit credentials** (zero vars since session-006's "Step 1" blocker); registered all 3 Xendit callback channels (`qr_code`/`ewallet`/`fva_paid`) via real API calls — `SUCCESSFUL`, `environment: LIVE`; rotated DOKU creds; confirmed the extra `doku_key_…` value the user offered isn't consumed anywhere in this codebase (SNAP-only, no checkout widget); flipped `PAYMENTS_DEFAULT_GATEWAY` `midtrans`→**`xendit`** (first gateway to ever process real prod money — Midtrans's real merchant has held zero activated channels since session-019); set `BRIMO_SECRET_KEY` (BRI's published dev key) + `BRIMO_ENVIRONMENT=dev` on prod infra per the new Stage-1 staging doc. **Real Playwright smoke test, not synthetic:** fresh test organizer signed up live (OTP read from Redis, no inbox access), KYC/MoU patched directly to unlock `PAID_PLATFORM`, event + free/paid ticket types created and published; free-ticket path driven through a **real BullMQ `wa-inbound` job** (same code path a genuine WhatsApp webhook triggers) → `PAID`/`ISSUED`; paid-ticket path minted a **real Rp 1.000 QRIS** (merchant name visibly "PT BIJI INOVASI GRUP") that **the user scanned and paid with their own phone** — the real Xendit webhook landed `200` (not the session-020 `401` failure class) → `PAID`/`ISSUED`, e-ticket emailed. **Found (pre-existing, unrelated):** the WhatsApp `eticket` template fails platform-wide (`Graph API #132001`) — also hit an unrelated real order the same morning; email delivery covered it. All 13 touched tables + matching Redis keys deleted/verified zero-residue after. **Written up retroactively** — prod has since moved further via sessions 028-033; see those and the Production footprint section for current state. |
| [035](session-035-2026-07-23.md) | 2026-07-23 | Activate real organizer **"Ocarinesia"** (`org_b6966137a3254ada`) for platform payment collection — KYC verified, MoU signed, verification badge | Traced identity via the Redis-only account→organizer link (`account.primary_phone` → `membership:{phone}` → `org_b6966137a3254ada`, slug `ocarinesia`); found `organizer_account.status` already `ACTIVE` but `kyc_status=UNVERIFIED` and `mou_status` reset to `GENERATED` by an accidental MoU-regenerate one minute after the user had already signed it earlier the same morning (superseded the signed doc, per the ladder's own versioning design). Plan reviewed + approved by user before any write. Direct-DB'd the same effect as the operator console's `kyc.approve`/`mou.sign` actions (`organizer_payout_profile.kyc_status→VERIFIED`, `mou_status→SIGNED`; `mou_document.status→SIGNED`) plus `organizer_account.verification_badge→VERIFIED` (user-requested), all in one transaction, independently re-verified after commit. Deliberately did **not** hand-write matching `operator_audit_log` rows — that table is sha256 hash-chained and append-only; fabricating entries in a compliance-relevant audit trail isn't appropriate even when algorithmically correct, so this session file is the record instead. Re-derived `deriveOrganizerPaymentCapability` by hand: stage now **`PAID_PLATFORM`** (platform-only, per user's explicit choice — no Xendit DIRECT approval added). Org has no BYO gateway keys, so it collects via the platform's own Xendit (live, BRI/BNI/MANDIRI/PERMATA VAs since session-032). Payout bank details left empty — user explicitly deferred ("no need payout"); collection works without them, disbursement will need them later. |
| [036](session-036-2026-07-23.md) | 2026-07-23 | **Live production payment-gateway smoke test** — QRIS, generic VA, BRI VA (BRImo), BNI/BRI diagnostic, all via the **platform** Xendit gateway | Real disposable organizer (email-OTP signup, OTP read from Redis since `devCode` is prod-disabled) pushed to PAID_PLATFORM tier (KYC via a disposable operator account, MoU via organizer self-service) → real event + paid ticket type published → 3 real buyer checkouts, concurrently with session-035's real Ocarinesia activation (explains this session's own +2 order/payment_intent delta, independently verified as unrelated). **QRIS ✅** real Xendit QR (not the fake-provider marker). **Generic VA ❌** real `400 BANK_NOT_ACTIVATED_ERROR` for BCA (confirmed `collectionMode:PLATFORM`, zero stray `payment_intent`) — root cause: the method is hardcoded to `bank_code:'BCA'`, the one bank not activated on the platform account. **BRI VA via BRImo ✅** real VA, decrypted from the redirect payload. **Diagnostic** (`xendit-channels.ts`, bypasses the app): both BRI and BNI mint fine on the platform key — proves the VA failure is avoidable, not a Xendit-side gap. Filed as a known issue (doc only, fix deferred per user instruction) — 3rd local-only commit on top of session-033's pending push. All test data (org/event/tickets/orders/intents/operator) deleted; row-count diff independently verified as real unrelated traffic (session-035's), not leakage. |
| [037](session-037-2026-07-23.md) | 2026-07-23 | **Root-cause: "Malang Creative Fusion" BRImo "belum aktif"** (their own Xendit account has BRI **Fixed-VA** off — a Xendit-side bug) + built a **VA-activation proof script** + found **v3 Payments** as an in-app workaround | Read-only investigation + tooling + docs; no deploy/config/app-code change. MCF = `org_03f297927f184c0d` = the org sessions 031/032 called **EPOCHSTREAM** (Xendit business `67e001d933376768bcd990ff`, `account_holder_name:"EPOCHSTREAM"`), running "Festival Mbois 11". **Root cause:** MCF collects **DIRECT** through its own key `…5GIJ` whose BRI Fixed VA returns `BANK_NOT_ACTIVATED_ERROR`, so the BRImo BRI-VA mint 422s "belum aktif"; Ocarinesia works because it collects **PLATFORM** (platform account has BRI). Proven 4 ways (`organizer_payment_method_status` DIRECT/BRIMO=NOT_ACTIVATED, 10 live API logs, live Playwright repro, `embed_page` scope = 1 active BRImo embed). Built **`scripts/check-xendit-va-activation.mjs`** (dependency-free, safe to hand to the organizer) probing **Fixed VA / Invoice VA / v3 Payments** per bank; ran on the platform key + MCF's decrypted key. **Invoice VA is NOT an escape hatch** (raw dump: BRI `collection_type:POOL`, no `bank_account_number`, on create + GET-refetch — hosted-page only; binding a Fixed VA needs an active Fixed VA). **v3 `/v3/payment_requests` IS** — returns a raw 17-digit BRIVA prefix `13282` (same corp code as working BRImo VAs) even with Fixed VA off, tapping the VA-Aggregator activation the org already has. **Re-confirmed a Xendit-side bug:** MCF re-activated BRI Fixed VA + confirmed, yet the API still 400s. Updated `known-issues.md` (escape-hatch findings + dev-agent note: migrate BRImo VA mint to v3 Payments — redirect builder unchanged, new `payment.succeeded` webhook the real work, verify end-to-end first). App-repo commits `7e6cf7df`/`5056cec9`/`99d0ef0b`. No `payment_intent` persisted for any failed attempt; all Xendit test artifacts unpaid/auto-expiring. |
| [038](session-038-2026-07-23.md) | 2026-07-23 | Deploy **per-bank VA selection + Xendit Fixed→v3 fallback** (38 commits) to prod; hit + worked around a **`drizzle-kit migrate` CLI failure** | `fc32f4f1`→`66c1a329`; **+2 migrations** (106→108, additive `organizer_account.disabled_va_banks` + `organizer_payment_method_status.bank_code`). Buyers now pick a VA bank, organizers toggle banks per-method, and the Xendit adapter falls back Fixed→v3 when a bank sits on the VA-Aggregator track but not Fixed VA (the fix that came directly out of session-037's BRImo root-cause). Caught that the new deploy note's "no DB migration" claim only covers the later of the two bundled merges — checked the migrator cursor (`1784778344153`) against both new `when` values before running, confirmed no repeat of sessions 032/033's cursor-skip landmine. **`pnpm --filter @eventopia/db db:migrate` failed outright** (CLI swallowed the real error behind its spinner, `ERR_PNPM_RECURSIVE_RUN_FIRST_FAIL`, no partial DDL) — worked around via the direct `drizzle-orm` migrator script (`run-migrate.mjs`, already sitting untracked on prod from session-032/033), which applied both migrations cleanly; independently verified via `information_schema`. Console (0.30.0)/web-public (0.21.0) rebuilt, api (0.40.0)/workers restarted; operator/checkin untouched. All 4 processes stable, 0 crash loops. **Live-proved the v3 fallback against real Xendit** (platform key, `PROBES=fixed,v3 BANKS=BRI` — both return a raw BRI VA, `13282…` prefix) and Playwright-verified MCF's real checkout page (0 new console errors). **Not done — carried forward:** the mandatory Xendit Dashboard "Payment" webhook (platform account + MCF's DIRECT account) — without it a v3-minted VA mints but never settles; MCF's BRImo is therefore still not fully fixed in practice. |
| [039](session-039-2026-07-24.md) | 2026-07-24 | **Live payment smoke test** — baseline (disposable org) + Ocarinesia (real event, all methods) + MCF (real BRImo event); found + filed a real bug | No deploy/config change — pure verification of session-038's deploy via real `POST /v1/payments` calls against real Xendit, all test data deleted after (0 residue verified against real pre-existing baselines). **Baseline (disposable org):** QRIS/VA(BRI)/BRIMO all ✅. **Ocarinesia** (all methods, nothing organizer-disabled): QRIS ✅, VA BRI/BNI/MANDIRI/PERMATA ✅ (4 real VAs), BRIMO ✅; VA-BCA correctly rejected by Xendit but **found a real bug** — the app returns it as a retryable 503 instead of terminal 422 (v3's `INVALID_MERCHANT_SETTINGS` isn't in `CHANNEL_NOT_ACTIVATED_CODES`), filed in the app repo's `known-issues.md` (`2dfcb741`, not pushed); e-wallets (GOPAY/OVO/DANA/SHOPEEPAY) initially failed on my own test's missing fields (`returnUrl`/buyer phone), retried correctly and confirmed genuinely NOT_ACTIVATED — a Xendit-dashboard gap, not a code bug. **MCF (real live "Festival Mbois 11 - Concert by BRImo"):** QRIS ✅ (own DIRECT account, merchant "EPOCHSTREAM"); **BRIMO ✅ — the actual target** — minted via the v3 fallback (`providerPaymentId` prefixed `pr-`), the exact flow that 422'd before session-038. Mint proven; full real-money settlement not yet exercised (dashboard webhook confirmed set by the user). |
| [040](session-040-2026-07-24.md) | 2026-07-24 | Deploy **collect-early + DIRECT self-service + share-QR/OG images + 4 fixes** (90 commits) to prod; live registration-to-payment smoke test; found the `/e/` short-link Cloudflare gate is live-broken | `66c1a329`→`9d06e015`; **+2 migrations** (108→110, additive short-code/short-link-scan + `organizer_account` status-collapse data migration, pre-checked against real prod data — 8 rows, 0 BANNED). Same `drizzle-kit migrate` CLI failure as session-038, worked around the same way (`run-migrate.mjs`). Console/admin/web-public rebuilt (og-fonts verified landed, 14/14), api/workers/console/web-public/**eventopia-operator** (=`apps/admin`) restarted; checkin untouched. **Live smoke test (user-requested, registration→payment):** fresh non-KYC organizer published a **paid event with zero KYC/MoU** (collect-early proven live, not just backfilled) and collected via all 3 methods — QRIS ✅, VA(`bankCode:BRI`) ✅ real `13282…` VA, BRIMO ✅ (decrypted redirect confirms genuine BRI VA tied to the real event); also spot-checked `days[]`, powered-by footer, OG image + QR PNG — all live. 10 test rows + 2 Redis keys deleted, 0 residue, `organizer_account` total back to exactly 8. **Found (confirmed twice, fresh code):** `eventopia.my/e/<code>` still 301s into a real 404 on the marketing site — the apex Cloudflare edge rule swallows `/e/` paths; any printed share-QR poster is dead until a dashboard exemption is added — **deferred to the user to fix directly.** User set a standing rule this session: smoke-test cleanup must only ever touch test-created rows, never real data. |
| [041](session-041-2026-07-25.md) | 2026-07-25 | ✅ **Fix** the `/e/` short-link 404 from session-040 — root cause was **`proxy`'s own nginx, not Cloudflare** (the app repo's docs were wrong about this); hit + fixed a classic nginx **`return`-in-`server{}` phase-order bug** along the way | Chased Cloudflare first per the docs' explicit claim — systematically ruled out all 4 mechanisms (Page Rules, Redirect Rules, Bulk Redirects, Workers Routes all empty, via a scoped `CF_API_TOKEN` the user progressively granted more permission to). `grep`'d `proxy`'s nginx configs instead: found a plain `server_name eventopia.my { return 301 https://eventopia.co.id$request_uri; }` block — the docs' "no origin headers" reasoning was a false signal (Cloudflare always overwrites `Server:` to `cloudflare` regardless of origin). **First fix attempt failed**: added a `location /e/ {...}` block ahead of the bare `return`, but a `return` directly in `server{}` runs in nginx's server-rewrite phase, *before* location matching — it fires unconditionally and the location block never gets evaluated. **Real fix:** wrapped the fallback in its own `location / { return 301 ...; }` so both compete normally. Backed up first (`eventopia.conf.bak-20260725-pre-e-route`), `nginx -t` clean, reloaded. **Verified both direct-to-origin (bypassing Cloudflare via `--resolve`) and through Cloudflare:** `eventopia.my/e/SNKJP7` → `302` → `https://ocarinesia.eventopia.my/international-ocarina-festival`, `cache-control: no-store` — matches the launch doc's documented correct outcome exactly. Apex root still 301s to marketing, no regression. **Also fixed both launch docs' incorrect "it's Cloudflare" claim** same session (commit `885289cf`, local-only — push decision pending), explaining why the original header-based reasoning was a false signal and adding a bypass-Cloudflare curl recipe for next time. |
| [042](session-042-2026-07-27.md) | 2026-07-27 | Investigate "expired tickets but details say failed" — confirmed **NOT a data bug**, filed as a UX-clarity gap | Read-only investigation (`app` code + `db` queries), no deploy. `orders.status` (PENDING/PAID/CANCELLED/REFUNDED/EXPIRED) and `payment_intent.status` (PENDING/SUCCEEDED/FAILED) are separate, disjoint-enum fields shown on the same admin order-detail page — an order can legitimately be `EXPIRED` while one of its payment attempts is `FAILED`; the code deliberately lets a failed attempt leave the order `PENDING` for retry (`settlement.ts:176`), only the reservation-TTL sweep moves it to `EXPIRED`. Tickets have no `EXPIRED` status at all (only issue on `PAID`) — confirmed live: 0 tickets across all 95 `EXPIRED` prod orders (52 no attempt / 34 attempt still `PENDING` / 9 attempt `FAILED`). Filed with file:line pointers + the live-data breakdown in the app repo's `known-issues.md`, framed explicitly as UX (not logic) — commit local-only, not pushed. |
| [043](session-043-2026-07-29.md) | 2026-07-29 | Deploy **crew invite confirmation + domain-split correction + collect-early hardening + web embed + partner-gate + Xendit v3 422 fix** (96 commits, largest since session-025) to prod; full live smoke suite; found + fixed a live nginx gotcha | `9d06e015`→`dd74318e`; **+2 migrations** (110→112, both additive: `0110` payout-profile identity columns, `0111` staff-invite-confirmation columns+index). Found + fixed live: the new `/i/<code>` apex page needed a `/_next/` static-asset nginx exemption too, not just its own `location` block (unlike `/e/`'s pure-redirect route, `/i/` ships a real client bundle) — fonts CORS-failed through the apex→co.id redirect until fixed, page itself stayed functional throughout. **Live E2E smoke test, full recipe:** disposable-org signup→KYC→MoU→PAID_PLATFORM→event→real QRIS intent (left to expire, cleaned up); **crew invite confirmed live end-to-end using the user's real phone** (`INVITED`→`ACTIVE`, real WhatsApp round-trip); **partner-invite-gate confirmed live** via signed synthetic webhooks (un-invited number → `rejected`, clean no-fail-open path); **Xendit v3 422 fix confirmed via the real app code path** (BCA VA → `422 PAYMENT_METHOD_NOT_ACTIVATED`, not the old 503 — closes session-039); payout-account encryption backfill run (1/15 legacy row encrypted). 3 findings filed in the app repo's `known-issues.md`/deploy note (nginx gotcha, a `check-xendit-va-activation.mjs` crash bug, a pre-existing harmless domain-var drift) — commit local-only (`78d02b2d`), not pushed. All test data cleaned zero-residue (caught + fixed one cleanup bug: `organizer_account.id` isn't the `org_...` value, it's a separate `organizer_id` column); deliberately left one real pre-existing Redis key untouched (the user's real phone's genuine Ocarinesia membership from session-035). |

## Production footprint (`app` / eventopia.my + eventopia.co.id)

CF (orange, **`eventopia.my` zone now Full, not strict** — flipped session-024 to unblock custom
domains) → `proxy` nginx → `app` `10.0.0.5:380xx` (PM2 under `devops`, Next bound
`10.0.0.5`). DB+Redis on `db` `10.0.0.1` (PG16, role `eventopia` w/ `BYPASSRLS`, **Redis db6**). Bun +
pgvector installed as prereqs. No seed. checkin static served from proxy — **fixed and live as of
session-029** (was white-screening since ≥2026-06-24, see session-027). **112 migrations applied
(session-043, `0110`/`0111` — both additive, no landmine). Code at `dd74318e` (session-043) — crew
invite confirmation over WhatsApp, a domain-model correction (`.env.example`/source defaults now
consistently say `eventopia.my` is the tenant root, `eventopia.co.id` is "us"-only), collect-early
hardening (unverified-collection cap, payout encryption at rest, identity KYC), web embed, the
partner/panitia invite gate, AI page style kits, and the Xendit v3 422 fix (96 commits since
session-040's `9d06e015`).** The apex `eventopia.my` nginx server (`proxy`) now has three
capability-path exemptions from its blanket `→eventopia.co.id` redirect: `/e/` (session-041),
`/i/` and `/_next/` (session-043 — the latter because `/i/` is a real rendered page, not a pure
redirect like `/e/`, so it needs its static-asset chunks routed same-origin too). BRImo/BRI-VA
collection remains broken **in practice** for `org_03f297927f184c0d` (EPOCHSTREAM/MCF) — the v3
fallback code is live and proven against Xendit's real API (session-038), but the required Xendit
Dashboard "Payment" webhook hasn't been set yet, so a v3-minted VA would mint but not settle. See
the Payments section below and sessions 032/037/038. Separately, **the Xendit v3 "not activated"
misclassification (a bank dead on both VA surfaces got a retryable 503 instead of a terminal 422)
is fixed as of session-043** — closes session-039's filed finding, confirmed live against the
platform account's dead BCA channel.

**Google sign-in (session-028):** "Continue with Google" on the organizer console, via better-auth
— OAuth dance only, bridges into the same identity funnel as every other login channel (one account
per verified email regardless of channel). Live and verified end-to-end (real Playwright click-through
to `accounts.google.com` with the correct prod OAuth client). `GOOGLE_CLIENT_ID`/`SECRET`/
`API_BASE_URL`/`CONSOLE_BASE_URL`/`BETTER_AUTH_SECRET` all set; `NEXT_PUBLIC_GOOGLE_LOGIN_ENABLED=true`.
Full setup/troubleshooting doc: `docs/engineering/google-login.md`. `ba_*` tables (migrations 0098/99)
are RLS-enabled-not-forced with zero grants to `app_tenant` — fail-closed by design, not by accident.

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

**New (session-042):**
- **App-repo commit adding the `EXPIRED`-vs-`FAILED` UX-clarity entry to `known-issues.md` is
  local-only, not pushed to `origin/main`** — same "push decision needed" pattern as sessions
  032/033/036/039/041.
- **Not a bug, no fix required** — filed as an optional UX improvement (explainer copy near the
  "Payment attempts" card) for whoever next touches the admin/console order-detail pages; not
  scheduled.

**New (session-041):**
- **App-repo commit `885289cf` (docs correction) is local-only, not pushed to `origin/main`** —
  same "push decision needed" pattern as sessions 032/033/036/039.

**Resolved (session-041):**
- ~~Docs incorrectly claim the apex redirect is "a Cloudflare edge rule, not anything in this
  repo"~~ — **fixed.** `docs/launch/event-share-qr-deploy.md` §1 and
  `docs/launch/brimo-sandbox-validation.md` both corrected to state the real mechanism (`proxy`'s
  own nginx), why the original header-based reasoning was a false signal, and a bypass-Cloudflare
  curl recipe for next time.
- ~~`eventopia.my/e/<code>` short links are live-broken~~ — **fixed.** Root cause was `proxy`'s own
  nginx (not Cloudflare as the docs claimed), plus a self-inflicted nginx phase-order bug in the
  first fix attempt (`return` in `server{}` beats any `location{}` regardless of specificity).
  Verified working both direct-to-origin and through Cloudflare against a real event
  (`eventopia.my/e/SNKJP7` → correct `302` to the tenant page). See session-041 for the full trace.
- **Optional, non-blocking:** a Cloudflare Cache Rule for `/opengraph-image` + a rate limit (nginx
  on `proxy` recommended) — pure cost/performance, detail in `docs/launch/og-images-cloudflare-deploy.md`.
- **Policy heads-up:** DIRECT collection is now self-service (operator approval gate removed this
  deploy) — any KYC+MoU-verified organizer can route real buyer money to their own gateway account
  with no human review. Worth a proactive mention to product/ops if that review was load-bearing.
- Standing rule set by the user: smoke-test cleanup must only ever delete rows/keys the test itself
  created (exact captured IDs), never real data — saved to memory
  (`feedback_never_delete_real_data`).

**New (session-039):**
- **A real bug was found and filed, not yet fixed:** the Xendit v3 fallback (session-038) mints
  correctly on every rescued bank, but a bank dead on **both** Fixed VA and v3 (BCA on the
  platform account today) gets misclassified — buyer sees a retryable 503 instead of the correct
  terminal 422. Root cause + fix direction filed in the app repo's `docs/engineering/known-issues.md`
  (commit `2dfcb741`, **local-only, not pushed** — same pattern as sessions 032/033/036). Suggested
  fix is a one-line addition to `CHANNEL_NOT_ACTIVATED_CODES` in `packages/payments/src/errors.ts`.
- **E-wallets (GOPAY/OVO/DANA/SHOPEEPAY) are not activated on the platform Xendit account at all**
  — confirmed via real `POST /v1/payments` calls with correct required fields (`returnUrl`/buyer
  phone), all 4 correctly 422 `NOT_ACTIVATED`. Not a code bug — needs Xendit dashboard activation
  before any e-wallet checkout can work platform-wide.
- **BRImo-on-MCF: mint proven live, settlement still unproven with real money.** The Dashboard
  "Payment" webhook is confirmed set (platform + MCF's DIRECT account), and the mint step works
  end-to-end via the v3 fallback, but no completed real payment has been run through it yet —
  worth closing with one small real transaction next time this org is touched.

**New (session-038):**
- **The mandatory Xendit Dashboard "Payment" webhook step has NOT been done** — per
  `docs/launch/xendit-va-v3-fallback-deploy.md`, a v3-minted VA **mints but never settles** until
  the Dashboard webhook is pointed at `/webhooks/payments/xendit` (platform account) and
  `/webhooks/payments/xendit/{organizerId}` (each DIRECT org, e.g. MCF/EPOCHSTREAM
  `org_03f297927f184c0d`). This is a manual, out-of-band action only the account owner can do.
  **MCF's BRImo is therefore still not fully fixed in practice** even though the code fallback is
  live and proven against Xendit's real v3 API this session.
- `drizzle-kit migrate`'s CLI failed outright on this deploy (spinner swallowed the real error,
  generic `ERR_PNPM_RECURSIVE_RUN_FIRST_FAIL`) — worked around via the direct `drizzle-orm`
  migrator script rather than root-caused. Same family as session-009's "silent-failure gotcha".
  If it recurs a third time, worth reading `drizzle-kit`'s own migrate-command source the way
  sessions 032/033 read `drizzle-orm`'s migrator source. The workaround script
  (`~/eventopia/run-migrate.mjs` on prod, untracked) is now de-facto load-bearing — consider
  committing a proper version instead of leaving it as a stray on-host file.
- No reconciler backstop for v3-minted VAs yet (`getPaymentStatus` doesn't poll `pr-…` ids) — a
  dropped `payment.capture` webhook has no automatic recovery. Watch via the SQL query in
  `docs/launch/xendit-va-v3-fallback-deploy.md` if a v3 VA order looks stuck once the dashboard
  webhook is set.

**New (session-037):**
- **MCF ("Malang Creative Fusion" / `org_03f297927f184c0d`) BRImo still down — Xendit-side bug.**
  Business `67e001d933376768bcd990ff`, live mode: BRI *Virtual Account (Fixed)* shows Activated in
  the dashboard but the API returns `BANK_NOT_ACTIVATED_ERROR`, and this **persists across a fresh
  re-activation** the organizer performed + confirmed. Only Xendit can fix it — escalate. Interim
  (per `known-issues.md`, not applied this session): turn `brimo_enabled` off for MCF or steer the
  embed to QRIS (works DIRECT on their account) so the CTA stops stranding buyers.
- **Durable in-app workaround, filed for a dev agent:** migrate the BRImo BRI-VA mint from
  `/callback_virtual_accounts` (Fixed VA) to `POST /v3/payment_requests` (v3 Payments) — it returns
  a raw BRI VA number on MCF's account **today** (corp code `13282`), tapping the VA-Aggregator
  activation the org already has. Step-by-step note in `docs/engineering/known-issues.md`: the
  BRImo redirect builder is unchanged, the real work is the new `payment.succeeded` settlement
  webhook (not `fva_paid`); **verify end-to-end with one real payment before shipping** (the v3
  number is proven returned, not proven to settle).
- **New tool of record:** `scripts/check-xendit-va-activation.mjs` (app repo) probes Fixed VA /
  Invoice VA / v3 per bank in one run, safe to hand to organizers (env-var key, no email, unpaid
  auto-expiring test artifacts). Supersedes ad-hoc `xendit-channels.ts` runs for the VA-activation
  question. `PROBES=fixed,invoice,v3` toggles surfaces.

**New (session-036):**
- **Push decision needed (updated from session-033):** now **3** local-only commits in
  `/Users/dedi/Projects/eventopia` (`deeaec50`, `8a5201e8`, `2db1f4c7`) — the migration-journal
  fix plus a new known-issues.md entry (generic VA hardcodes `bank_code:'BCA'`). None pushed to
  `origin/main` yet.
- **Generic `VA` payment method needs bank selection** — hardcoded to `bank_code:'BCA'`
  (`packages/payments/src/xendit.ts:568-586`), which happens to be the one channel not activated
  on the platform Xendit account, so every generic-VA checkout currently 422s. BRI/BNI both mint
  fine on the same key (confirmed live this session) — the fix is code (accept/auto-select a
  bank), not a Xendit dashboard change. Documented only, per user instruction — fix deferred to a
  dedicated session. See session-036.
- Minor, not filed: organizer signup's `organizerSlug` input appears ignored in favor of an
  auto-derived slug from `organizerName` — worth a quick look next time signup is touched.

**New (session-035):**
- **Ocarinesia (`org_b6966137a3254ada`) still has no payout bank details** — `organizer_payout_profile.destination_bank_code/account_number/account_name` are empty. Collection now works (`PAID_PLATFORM`, platform Xendit), but disbursement can't run until the organizer fills these in themselves (Console → Settings → Payouts). User explicitly deferred this ("no need payout") — not a bug, just a known gap to remember before they expect a real payout.
- The account→organizer link is **Redis-only, no Postgres FK** (same gotcha session-017 flagged for `event`/`organizer_account`) — looking up an organizer by a human-readable name means: find the `account` row → get `primary_phone` (or `acc:{id}` subject for email-anchored accounts) → `GET membership:{subject}` in Redis db6 → `organizerId`. Worth remembering the exact chain next time an org needs to be found by name rather than id.

**New (session-033):**
- **Push decision needed:** the migration-journal fix (2 commits, `deeaec50` + `8a5201e8`,
  in the local `/Users/dedi/Projects/eventopia` clone) is not yet pushed to `origin/main`. Until
  it lands, a fresh clone/CI still carries the dormant `0019`–`0027`/`0102` landmine.
- `docs/launch/payment-method-status-deploy.md`'s migrate command is missing the
  `DATABASE_URL='<prod>'` prefix that the sibling `payments-default-gateway-deploy.md` correctly
  includes — caused this session's first `db:migrate` attempt to fail outright. Small doc fix.
- `dev` not checked for the `0019`–`0027`/`0102` exposure — out of scope (prod-only session),
  likely already fine given dev's own incremental history, but not directly verified.
- Backup location convention has drifted (session-032 used `app:~/db-backups/`, this session used
  `db:/root/eventopia-backups/`, both valid) — worth standardizing.

**New (session-032):**
- **Platform Xendit account: BCA VA channel still not activated** — after ops activated BRI/BNI/
  MANDIRI/PERMATA directly in the dashboard, only BCA remains `BANK_NOT_ACTIVATED_ERROR` on the
  platform key (re-measured live via `scripts/xendit-channels.ts --create`). E-wallets/QRIS not
  re-verified this pass. Same dashboard-activation fix, much narrower than the prior "every channel
  disabled" state.
- **EPOCHSTREAM (`org_03f297927f184c0d`) BRImo/VA collection still fully broken** — the reported
  outage runs DIRECT through the organizer's OWN Xendit account, so the platform-side activation
  above does not touch it. Re-test showed only BNI mints on their key; BRI/BCA/MANDIRI/PERMATA all
  still 400. Needs the organizer to escalate to Xendit support (business `67e001d933376768bcd990ff`);
  consider disabling `brimo_enabled` so the CTA stops stranding buyers. (Same root issue tracked in
  the 031 block.)
- ~~Migration-journal timestamp bug made `0102` silently no-op~~ — **resolved by session-033** (repo
  `_journal.json` monotonicity fixed; see the 033 block, which also found session-032's manual
  `Date.now()` tracking-row insert had triggered the same skip for `0103`).
- **Product/eng decision needed, not an organizer action:** initial read (organizer needs to
  activate BRI on their Xendit account) was disproven — the **platform's own** Xendit key hits the
  identical `400 BANK_NOT_ACTIVATED_ERROR`. Root cause is that the integration calls Xendit's
  **Fixed VA** product (`/callback_virtual_accounts`) but this business only has BRI activated
  under **Invoice VA** (separate Xendit activation tracks, confirmed against Xendit's own docs).
  Needs a decision between requesting Fixed-VA BRI activation (doesn't scale to every
  DIRECT-collecting organizer) or re-architecting BRI-VA creation onto the Invoice-VA product.
  Filed in the `eventopia` repo's `docs/engineering/known-issues.md`; **not fixed, not committed**.
- **Code-fixable, not yet implemented:** payment-collect failures (`apps/api/src/modules/payments/module.ts:103-107,179-184`)
  never log the underlying gateway error before mapping to the generic 503 — every occurrence
  needs a live reproduction to diagnose, as this session had to do twice. Filed alongside the above.
- **`dev` host (`154.26.130.96`) SSH lockout:** port 22 refuses connections outright (ICMP still
  fine) after this session's own failed-credential attempts — likely fail2ban. Blocked testing
  BRImo on dev/sandbox as requested; needs unbanning before that follow-up can run.
- **Doc-hygiene gap noticed, not fixed:** `known-issues.md`'s check-in white-screen entry is still
  marked `🔴 LIVE OUTAGE, FIX READY PENDING DEPLOY` even though session-029 deployed and verified
  that fix — and session-030's own report says it removed that entry + added the duplicate-slug
  bug, but neither change is actually present in the file or its git history. Worth reconciling
  next time either bug is touched.

**Resolved (session-030, closed 2026-07-23) — no longer open:**
- ~~Event-creation 500 on duplicate slug~~ — **fixed and live**, `05811823`/`85084060` (2026-07-22
  evening, same-day as this session's investigation, independently by another coding-agent session),
  shipped in session-032's deploy, confirmed present in prod's current checkout (`fc32f4f1`). See
  session-030's Update section for the full verification.

**New (session-030), low priority:**
- Whether the pre-existing `evt_8543d237-2d6a-4873-97d8-391bbc2ffd0b` ("Festival Mbois 11 - Concert",
  `DRAFT`, created 2026-07-17) is wanted or just a forgotten leftover is still an open question for
  the user — but no longer *blocking*, since creating another same-named event now auto-disambiguates
  the slug instead of erroring.

**New (session-029):**
- **`checkin.dev.eventopia.my` still white-screens** — the `dev` host carries the same defect with
  its own key value (`SXKtc6W8-wRzdT0JkxuRRJGUag_mDzzCR0Xeyhw5f54`, computed session-027), explicitly
  out of scope for this prod-only deploy. Needs its own `.env` fix + rebuild + rsync on `dev`.
- **Tell door staff:** installed devices need two loads to recover post-deploy (Workbox precache) —
  not yet verified against a real installed device, only a fresh browser load. Verify before any event.
- **`.env.example` doc gap:** `NEXT_PUBLIC_CHECKIN_URL` (read by `apps/console/lib/config.ts:77`) isn't
  documented in `.env.example` at all — found live-grepping, not from the docs. Small doc PR worth doing.
- Payment-methods UI, org-name onboarding, and domain-target/embed page are live but only
  route-reachability tested (no organizer login available this session) — worth a real click-through.

**New (session-028):**
- Nothing outstanding from the Google sign-in / policy-pages / WA-number deploy itself — verified
  end-to-end including a real click-through to Google's live sign-in page.
- **Worth documenting in `infra/DEPLOY.md`:** `pm2 restart <name> --update-env` does NOT re-read
  `ecosystem.config.cjs` (it reuses PM2's cached process definition instead of re-running the file's
  `parseEnv()`). After any `.env`-only change, restart via
  `pm2 restart ecosystem.config.cjs --only <names> --update-env` and confirm with `pm2 env <id>` —
  don't trust `pm2 list`'s "online" status alone, since a stale-env process still comes up fine.
  Session-028 hit this live (Google's redirect_uri stayed wrong until caught by a smoke test);
  sessions 008/013 hit an adjacent version of the same class of bug.

**session-027 — 🟢 check-in PWA outage resolved on prod (session-029), dev still open:**
- ~~`VITE_TICKET_PUBLIC_KEY` is the wrong encoding~~ — **fixed on prod (session-029)**, live and
  Playwright-verified (0 console errors, staff screen renders). **`dev` still has the same defect**
  (`.env:68`) — see session-029's new follow-up above.
- Repo hardening (shared `parseEd25519PublicKey` normalizer, build-time guard in
  `apps/checkin/vite.config.ts`, third `generate-keypair.ts` output line, tests) — **all shipped**,
  merged as part of the same branch session-029 deployed.
- **Deploy verification gap** (sessions 009/014 recorded `curl 200` only, which a white-screened SPA
  still returns) — closed going forward: session-029 verified with a real Playwright render + console
  error check, not `curl`.
- **Unanswered:** has any real event run check-in since 2026-06-24? If so, staff had no working
  scanner at the door for ~6 weeks. Still needs a direct answer from the user.

**New (session-026):**
- **BRImo Layer 2c is now config-ready but not yet exercised.** `org_3c6828c4cdd245af`
  ("Festival Mbois 11 - Malang Menyala") is Xendit-pinned + DIRECT-approved and dev has
  `BRIMO_SECRET_KEY` configured — the remaining steps are enabling BRImo for that org in
  Console → Settings → Payments, publishing an embed page bound to `host=brimo`, and testing
  on a phone with BRImo installed. See session-026 and `docs/launch/brimo-sandbox-validation.md`.
- BRImo Layers 2a/2b (production-key VA + phone, URL interception — no server needed) were
  still unrun as of session-026; a green Layer 2c on dev's sandbox key does not substitute for
  them (BRI real-network acceptance can't be tested on a sandbox VA).

**New (session-025):**
- **Prod is now behind dev** on both migrations (85 vs dev's 98) and features (refund requests,
  ticket groups, organizer landing pages, embed/BRImo groundwork, WA BYO numbers all live on
  dev only) — inverts the usual dev-catches-up-to-prod direction. Prod's pull of this range is
  a separate, larger task: real payment-gateway credentials, real Meta WABA, real S3 — dev's
  "leave unset" shortcuts don't apply there.
- BRImo Layers 2a (production-key VA + phone) and 2b (URL interception) are still unrun (see
  `docs/launch/brimo-sandbox-validation.md`). Dev is now current enough that Layer 2c is a
  config-only follow-up (set `BRIMO_SECRET_KEY`/`BRIMO_ENVIRONMENT`, point a test org's
  gateway at `xendit`, enable BRImo in Settings → Payments) rather than a deploy.
- `@whiskeysockets/baileys` installed on dev but its native build scripts were skipped by pnpm
  — harmless while `WA_GATEWAY_SOCKET=fake`; needs `pnpm approve-builds` before ever flipping
  dev to a real Baileys socket (`WA_GATEWAY_SOCKET=miaw`).
- No real WhatsApp BYO-number pairing tested yet on dev (fake transport only).

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
