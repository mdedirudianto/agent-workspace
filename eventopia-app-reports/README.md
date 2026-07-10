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
| [008](session-008-2026-07-10.md) | 2026-07-10 | **Register eventopia's WABA with `miaw-route`** (prod) | Found the WABA subscribed to **no** Meta app (dedicated app's webhook was a dead `local.biji.uk` tunnel); fixed by reusing the shared **BIJI Dev** app instead of registering a new dedicated one — `.env` `META_APP_ID`/`META_APP_SECRET` corrected, WABA subscribed to BIJI Dev via Graph API, `routes` row added in `miaw_route`; hit + fixed a PM2 `ecosystem.config.cjs` env-reload gotcha; verified end-to-end with signed synthetic webhooks, including after a concurrent session's redeploy (`3f2c631`) |
| [009](session-009-2026-07-10.md) | 2026-07-10 | Pull `main` (**Tier 0-2 gap remediation: auth, S3 storage, payments, full observability**) to **prod** | `3f2c631`→`34a5385` (40 commits, largest pull to date); **+3 migrations** (72→75, unified `account` identity + RLS); real S3 object storage adapter live (existing DO Spaces creds now used); GlitchTip+OpenObserve+OpenPanel+GA4 provisioned from scratch (new GlitchTip org, OpenObserve service account, 3 OpenPanel projects); hit + fixed a GlitchTip DSN hex-vs-UUID format bug (required refetching + rebuilding all 4 frontends), a `drizzle-kit migrate` silent-failure gotcha (fixed via `node --env-file`), and a `bun`-not-on-PATH build gotcha; Resend enabled then reverted to `stub` after test-send revealed the sender domain isn't verified (pending user input); OpenObserve app-side shipping still not landing (Bun compatibility suspected) — all 5 surfaces green, PM2 stable throughout |
| [010](session-010-2026-07-10.md) | 2026-07-10 | **Live production smoke test** — first-ever real organizer journey (email OTP → event → FREE order → PAID) | Prod `account`/`event`/`orders` were all 0 rows pre-session; email-OTP signup (real browser UI) → 5-step event wizard → publish → free order via direct API (buyer WA-checkout avoided — see findings) → `PAID` in ~2s → ticket `ISSUED`; all test data deleted, DB/Redis back to 0-row baseline. **Found:** OpenPanel analytics 100% broken on all 3 frontends (wrong endpoint, 0 events ever since session-009); buyer checkout is WhatsApp-only with no email alternative (always sends a real WA message); e-ticket email delivery status stuck `ENQUEUED` (unconfirmed send); email-signup orgs stuck with placeholder name "Organizer Baru" (no rename endpoint); public page share/copy-link points at a non-resolving `.co.id` host |
| [011](session-011-2026-07-10.md) | 2026-07-10 | Pull `main` (**Bun observability fix, Register Now CTA, WCAG contrast**) to prod | prod `34a5385`→`721de4a` (12 commits); no new migrations (75); rebuilt api/workers/web-public/console; added missing `NEXT_PUBLIC_CONSOLE_BASE` env var before build (would've baked `localhost` into the new CTA); **new finding:** OTel "duplicate registration" error on api+workers boot (non-fatal, 0 GlitchTip issues) and **OpenObserve log shipping confirmed still broken** post-fix (live before/after test, session-009's fix didn't resolve it); all surfaces green |
| [012](session-012-2026-07-10.md) | 2026-07-10 | Pull `main` (**email organizer registration**) to prod | prod `721de4a`→`00d7d27` (5 commits, console-only, no API/DB changes); rebuilt+restarted `eventopia-console` only (`0.4.1`→`0.4.2`); closes session-010 Finding 4 — new email signups can now set an org name at registration (existing "Organizer Baru" orgs still have no rename path); new copy strings confirmed baked into deployed bundle; 0 new GlitchTip issues |
| [013](session-013-2026-07-10.md) | 2026-07-10 | **Move operator console** `operator.eventopia.my` → `admin.eventopia.co.id` (prod) + reset forgotten `SUPER_ADMIN` password | New DNS A record + expanded `eventopia.co.id` LE cert (3rd SAN) + new nginx vhost on `proxy`; old `operator.eventopia.my` vhost removed entirely (no redirect, unused); `CORS_ORIGINS` updated on `app` (new origin doesn't match the `*.eventopia.my` tenant-pattern CORS rule); hit + fixed the same PM2 `ecosystem.config.cjs` env-reload gotcha as session-008; ran concurrently with session-012's console-only pull with no overlap; new companion script `reset-operator-password.ts` (reuses app's own hashing) used to reset `hi@eventopia.my`'s forgotten password, verified live login `200`; all checks green |
| [014](session-014-2026-07-10.md) | 2026-07-10 | Pull `main` (**smoke-test fixes A–E**) to prod + fix nginx drift from session-013 | prod `00d7d27`→`38b3b3c` (7 commits, all 6 apps); closes every session-010 finding: OpenPanel `apiUrl` (needed 2 new env vars + admin's distinct client-id override), buyer email-OTP checkout, e-ticket email status SENT/FAILED, share-link host fix, **and** fully closes org-rename (new `PATCH /v1/auth/org` for existing "Organizer Baru" orgs); also found+fixed session-013's nginx `sites-enabled`/`sites-available` drift and closed its flagged OpenPanel-CORS follow-up for `admin.eventopia.co.id` — briefly added a redirect for the retired `operator.eventopia.my` before finding session-013's explicit "no redirect" decision and reverting it; all surfaces green, 0 new GlitchTip issues |
| [015](session-015-2026-07-10.md) | 2026-07-10 | **Re-verify smoke-test fixes A–E with a real order** — closes session-014's "not exercised against a real order" gap | Fresh live rerun of session-010's smoke test on prod (`38b3b3c`, unchanged): all 5 findings confirmed fixed — OpenPanel events now land (0→19 in ClickHouse), buyer checkout completed via the new email-OTP UI path (zero WhatsApp involvement), e-ticket `email_delivery_status` flipped to `SENT` immediately (was stuck `ENQUEUED`), org name settable at signup **and** renameable after the fact, share-link now resolves on `.my`; found pre-existing non-test-looking data (4 accounts/events, real event names) predating this session — left untouched, flagged for the user to confirm; all test data created this session deleted, DB back to pre-session baseline |

## Production footprint (`app` / eventopia.my + eventopia.co.id)

CF (orange, **Full-strict**) → `proxy` nginx → `app` `10.0.0.5:380xx` (PM2 under `devops`, Next bound
`10.0.0.5`). DB+Redis on `db` `10.0.0.1` (PG16, role `eventopia` w/ `BYPASSRLS`, **Redis db6**). Bun +
pgvector installed as prereqs. No seed. checkin static served from proxy. **75 migrations applied
(session-009). Code at `38b3b3c` (session-014).**

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

**Payments (session-006):** DOKU + Midtrans live (`PAYMENTS_DEFAULT_GATEWAY=midtrans`); Xendit
unconfigured (no prod keys) — **payouts/disbursements are hard-wired to Xendit for every tenant
regardless of collection gateway**, so no organizer can be paid out until real Xendit keys land.

**Two-TLD split (session-003):** `eventopia.co.id` = public **marketing landing only** (apex + `www` →
the same `web-public` :38100 instance, via the `MARKETING_HOST` middleware guard). `eventopia.my` = the
**app** (`app.` console, `api.`, `<org>.` tenant pages, `checkin.`); its apex + `www` **301 →
eventopia.co.id**. Separate LE cert `eventopia.co.id` (DNS-01, same `.my` CF token). Isolated vhost
`eventopia-coid.conf` on proxy.

## Open follow-ups

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
