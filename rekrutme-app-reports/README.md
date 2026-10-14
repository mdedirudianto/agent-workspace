# rekrutme-app-reports

App-scoped reports for **Rekrut.Me** (`rkrt.me`) — an AI-powered recruitment platform for Indonesian SMEs
(github.com/biji-dev/rekrutme, local `~/Projects/rekrutme`). Companies post jobs, manage candidates, parse CVs
with AI, screen applicants and track the recruitment pipeline; applicants apply and track through public pages.

**Status: LIVE since 2026-10-14** (session-002): `v1.1.0`, smoke test passed; served at **`https://rkrt.me`** since session-003 (same day; `www` and `app.rkrt.me` 301 to it). Owner items
left: GlitchTip DSN, Uptime Kuma monitor, the owner's own sign-up; the first backup check is due 2026-10-15.

Single Next.js 16 app (App Router, React 19, TypeScript, pnpm; Drizzle ORM). Built as a **standalone** server
(`server.js`). Background work uses **pg-boss** (PostgreSQL-backed queues `parse-cv`, `screen-candidates`,
`send-email`) with the workers booted **inside the web process** (`src/instrumentation.ts`). **Postgres only — no
Redis.** External services: **Anthropic** (CV parsing + candidate ranking), **DigitalOcean Spaces** (CV files, logos),
**Resend** (transactional email). Deployed version 1.1.0 (tag `v1.1.0`; the checkout is `8d52e8f`: the tag plus the PM2 `merge_logs` fix and the `rkrt.me` origin docs).

**Why exactly one instance:** the login (5 / 15 min) and public-apply (20 / 15 min) rate limiters are in-memory per
process, and the pg-boss workers live in the web process. More than one PM2 instance multiplies the limits.
Fork mode, 1 instance, always.

## Deploy footprint (live since 2026-10-14)

**No Docker in production** (owner, 2026-10-11): bare-metal Node 22 + PM2 only. The repo's `Dockerfile` /
`docker-compose*.yml` are for local development and local rehearsal only — never use them on the cluster.

- **App host:** `app` (`devops@154.26.129.104` / `10.0.0.5`), `/home/devops/rekrutme` @ `8d52e8f` (`v1.1.0` + `merge_logs` fix + origin docs).
  PM2 process `rekrutme` — **fork mode, 1 instance**, Next standalone `server.js` under **nvm Node 22**
  (system default is v24.18.0; nvm has v22.22.0), `HOSTNAME=10.0.0.5 PORT=3160` (private-bound; 3150/3151 belong to
  hoteru-radho, 3160 is free), `TZ=Asia/Jakarta`, `ecosystem.config.cjs` (PM2 needs `.cjs`; `merge_logs: true`, so the logs are
  `~/.pm2/logs/rekrutme-out.log` / `-error.log`, which fluent-bit's glob matches). Secrets in `.env` (mode 600).
- **DB host:** `db` (`10.0.0.1`). Postgres 16.9 database `rekrutme`, owner role `rekrutme` (needs CREATE on the
  database: drizzle creates schema `drizzle`, pg-boss creates `pgboss` at app start). 12 migrations (0000–0011), 13 tables. **No seed in production** (the seed wipes every row). No Redis. The `backup` auto-discovery (backup-sysadmin
  session-003) picks up a new DB without config.
- **Proxy:** `proxy` (`46.250.234.153` / `10.0.0.2`). Vhost `rkrt.me.conf`, `server_name rkrt.me www.rkrt.me app.rkrt.me`;
  LE cert for the three names (HTTP-01 webroot unless a Cloudflare DNS token is provided); `client_max_body_size`
  >= 25M (30M planned, CV uploads up to 25 MB per request); Cloudflare real-IP restore scoped to this vhost
  (`set_real_ip_from` Cloudflare ranges + `real_ip_header CF-Connecting-IP`); vhost sends `X-Real-IP`, app runs with
  `TRUSTED_IP_HEADER=x-real-ip`. The app sends HSTS `includeSubDomains; preload`.
- **DNS:** Cloudflare (registrar Namecheap, expires 2027-02-23), orange-cloud, SSL/TLS must be **Full (strict)**.
- **Monitoring:** Uptime Kuma on `https://rkrt.me/api/health` (endpoint added by F38); GlitchTip project (DSN via
  `SENTRY_DSN`); OpenObserve via the existing fluent-bit PM2 log glob on `app`.
- **Env:** `AUTH_URL` / `NEXT_PUBLIC_APP_URL` (the latter is baked at build time) = `https://rkrt.me`
  (owner, 2026-10-14, session-003; `www` and `app.rkrt.me` 301 to it. The 2026-10-11 default was `app.rkrt.me`).
- **Not part of production:** the old dev instance `dev.rkrt.me` on the dev box (`deploy` user, PM2 `rekrutme`, `:7007`),
  running old code.

## Subdomain map

| Host | → | Service | Backend |
| --- | --- | --- | --- |
| `rkrt.me` | proxy | the app (landing, dashboard, public careers/apply/track pages, `/api/*`) | `rekrutme` `10.0.0.5:3160` |
| `www.rkrt.me`, `app.rkrt.me` | proxy | 301 to `https://rkrt.me$request_uri` (owner, 2026-10-14; `app` keeps links in the first emails working) | — (nginx redirect) |

Mail on `rkrt.me`: MX → Amazon SES inbound (ap-northeast-1); outbound via Resend (`resend._domainkey` DKIM and
`send.rkrt.me` return path present); `_dmarc` = `v=DMARC1; p=none; rua=mailto:dmarc@rkrt.me`.

## Open follow-ups

Owner actions (before session-002 can finish):

- [x] Cloudflare SSL/TLS **Full (strict)** for `rkrt.me` — set by the owner 2026-10-11.
- [x] Origin: **`rkrt.me`** (owner, 2026-10-14, session-003); `www` and `app.rkrt.me` 301 to `https://rkrt.me$request_uri`. (Session-002 first went live on `app.rkrt.me`, the 2026-10-11 default.)
- [ ] Optional: a Cloudflare DNS token for `rkrt.me` (enables DNS-01 / wildcard; otherwise HTTP-01 webroot, no wildcard,
      and "Always Use HTTPS" on the zone would break renewal).
- [x] Dedicated DigitalOcean Spaces bucket + a scoped key (the local dev bucket is shared with other apps). Bucket `rekrutme` (sgp1, private) created by the owner 2026-10-11; key pair received 2026-10-11; HeadBucket + List verified read-only (empty bucket). Write/delete/public-read ACL to be proven by the deploy smoke test.
- [ ] Anthropic: launch on the **local subscription token** (`ANTHROPIC_AUTH_TOKEN`, owner's call 2026-10-11, `ai:check` OK). The local API key fails (not workspace-scoped → needs `anthropic-workspace-id`). Owner replaces it later with a **workspace-scoped API key + spend limit**.
- [ ] Resend: launch on the **local key** (owner's call 2026-10-11; `email:check` delivered), sender `Rekrut.Me <noreply@rkrt.me>`. Owner rotates it later and checks the quota.
- [x] SES inbound for `privacy@`, `hello@`, `dmarc@` — confirmed OK by the owner 2026-10-11.
- [x] Legal: owner accepts the drafted privacy notice and apply wording (2026-10-11); formal legal review stays optional.
- [ ] Paperwork: ToS, DPA, DPIA, incident-response plan.
- [ ] Google sign-in **off at launch** (recommended; leave `AUTH_GOOGLE_ID` / `AUTH_GOOGLE_SECRET` unset).
- [ ] Put the production secrets in Vaultwarden (DB password, `AUTH_SECRET`, Anthropic, Resend, Spaces, GlitchTip DSN). `AUTH_SECRET` and the DB password exist only in `/home/devops/rekrutme/.env` (generated 2026-10-14).
- [ ] Rotate `ANTHROPIC_AUTH_TOKEN` (pasted into a chat session 2026-10-14; launched on it for the beta).
- [ ] Enable auto-renew for `rkrt.me` (expires 2027-02-23).
- [ ] **Fleet-wide (proxy-scoped):** `proxy` has no certbot deploy hook (`/etc/letsencrypt/renewal-hooks/deploy/` empty, webroot authenticator), so a renewed cert is served only after some later `nginx` reload. Add `renewal-hooks/deploy/reload-nginx.sh` (`nginx -t && systemctl reload nginx`) — affects every site, belongs in a proxy-sysadmin session. Found 2026-10-11.

Repo work before deploy (coordinator, done 2026-10-11; repo `main` f9d22ab, tag `v1.0.0`):

- [x] F37 privacy minimum: `/privacy` page, apply-form wording, consent + talent-pool opt-in stored, migration 0006, pool gated by opt-in.
- [x] F38 production hardening (plus F38b–F38d fixes): `ecosystem.config.cjs`, `scripts/build-standalone.sh`, nginx vhost example, `/api/health`,
      fail-fast env check, GlitchTip, robots/metadata, version 1.0.0.
- [x] `docs/deploy-runbook.md` v2: first install on this cluster, steps D0–D11, PM2 only, no Docker.
- [x] Targeted regression (suites 01, 02, 09, 11, 14: 0 FAIL; E2E 7/7), tag `v1.0.0`.
- [x] Owner's go for session-002; deployed `v1.1.0` on 2026-10-14.

Post-launch:

- [ ] Add the Uptime Kuma monitor and GlitchTip project (owner, UI). Logs: fluent-bit tails the files since 2026-10-14 07:40 WIB; confirm in the OpenObserve UI.
- [ ] Confirm the `rekrutme` DB appears in the `db`→`backup` pull and test one restore.
- [ ] Rate limiters are per-process: if the app ever needs a second instance, add a shared store (Redis) first.
- [ ] No automatic purge of old soft-deleted rows (candidates, jobs) — decide a retention policy.
- [ ] Decide the future of the old `dev.rkrt.me` instance (retire or keep as staging with new code).

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 1](session-001-2026-10-11.md) | 2026-10-11 | Production readiness assessment (read-only): app state (QA 429/431 PASS, E2E 7/7, v0.10.0), cluster survey of app/db/proxy/DNS, planned footprint, owner actions, deploy plan | Done |
| [Session 2](session-002-2026-10-14.md) | 2026-10-14 | First production deploy of `v1.1.0` (D0–D9): DB, build, PM2, vhost + LE cert, smoke test 13/13 PASS, log names fixed for fluent-bit (`merge_logs`) | Live; D8a/D8b/D10 owner, D11 2026-10-15 |
| [Session 3](session-003-2026-10-14.md) | 2026-10-14 | Origin moved from `app.rkrt.me` to `rkrt.me` (owner): rebuild with the new URLs, vhost swap, `www`/`app` 301; mini smoke PASS | Done |
