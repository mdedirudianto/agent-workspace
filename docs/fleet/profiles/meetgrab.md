# meetgrab — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** meetgrab-app-reports up to session-016 (2026-08-31), registry + hosts 2026-10-19, repo docs at `a70b444` (= `origin/main`; prod = `b8b9e8b`, 2 commits behind, both extension-only)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
- `~/Projects/meetgrab/apps/api/OPS.md`: §2 deploy (turbo build, migrations, version stamp, rollback, connection budget), §3 secret rotation, §3b Google sign-in, §3c billing/PayPal, §5 restore, §9–§12 smoke, GlitchTip, OpenObserve, usage ledger. **It owns the procedure.**
- Per-release guides in `docs/MeetGrab_*_Deploy.md` (latest: `MeetGrab_MidtransSandbox_Deploy.md`), `docs/midtrans/CHECKLIST_INTERNAL.md`, `KNOWN_ISSUES.md`, `infra/nginx/`.
- Workspace: [README](../../../meetgrab-app-reports/README.md) (current SHAs, web build env list, follow-ups), sessions [016](../../../meetgrab-app-reports/session-016-2026-08-31.md), [015](../../../meetgrab-app-reports/session-015-2026-08-10.md), [014](../../../meetgrab-app-reports/session-014-2026-08-02.md), [013](../../../meetgrab-app-reports/session-013-2026-07-27.md).

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| api | app | PM2 `meetgrab-api` (devops), cwd `~/meetgrab/apps/api`, `dist/server.js`, system node v24.18.0, `.env` via `--env-file`, no ecosystem file, **no `max_memory_restart`** | `10.0.0.5:8930` | `api.meetgrab.us` | cert `meetgrab.us` (apex/admin/api/www), **dns-cloudflare** `cloudflare-meetgrab.ini`, exp 2026-11-25, **no reload hook** |
| web | proxy | static `/var/www/meetgrab.us` (Astro build, 105 files on 10-19) | — | `meetgrab.us`; `www` 301 → apex | same |
| admin | proxy | static `/var/www/meetgrab-admin` (Vite SPA v0.7.0, bearer-token gated) | — | `admin.meetgrab.us` (**grey-cloud**) | same |
| extension | Chrome Web Store / AMO | not server-deployed | — | — | — |
| canary | app cron | `~/meetgrab-summary-canary.sh` 07:00/19:00 (app clock, CEST) | — | — | — |

- proxy vhosts: `meetgrab.us.conf`, `api.meetgrab.us.conf` (has `location = /v1/summaries` with a 100 s timeout **in the 443 server**, s004), `admin.meetgrab.us.conf`. Cloudflare orange + Full (strict) on apex/www/api.
- Chain of timeouts: API budget 90 s < nginx 100 s < client 110 s (s003).

## Data
- **Postgres `meetgrab` on db, owner role `meetgrab`, since session-007.** Migrations `0000`–`0006` applied (s012). Tables include `usage_daily`, `usage_user`, `uninstall_feedback`, Better Auth `user/session/account/verification`, `llm_usage_daily`, billing/payment tables. 9 MB, 0 connections at the 06:26 WIB survey. Nightly dump on backup (106 KB, 8 kept).
- No Redis. Summary jobs (`202 {jobId}` + poll) and per-IP rate limits are **in-process memory**: a restart drops queued and in-flight jobs (s005).
- The API runs with an empty `DATABASE_URL` too (feedback 503, usage skipped, summaries fine). It opens **two** pools of 5 (OPS §2).
- External: Anthropic via OAuth token (`ANTHROPIC_AUTH_MODE=oauth`, no refresh token), Gemini fallback, PayPal (creds empty, billing inert), Midtrans **sandbox** keys, Google OAuth.

## Deploy
- Mode: pull-on-host for the API on app; web/admin **built on app, deployed app → proxy directly** (`devops@app` → `root@proxy` since 2026-10-20; Mac relay is the fallback); no CD (repo workflows are stubs; Actions off org-wide).
- API: OPS §2. `git pull` on `main` → `pnpm install --frozen-lockfile` → **`pnpm turbo run build --filter=@meetgrab/api`** (never a bare `pnpm --filter … build`) → migrations **before** restart (`PGOPTIONS` lock/statement timeouts) → stamp `BUILD_SHA` + `BUILD_RELEASED_AT` in `apps/api/.env` → `pm2 restart meetgrab-api` → `pm2 save`.
- Web: no `.env` for web on app. Export the 6 `PUBLIC_*` vars inline (names and values listed in the README) plus `PUBLIC_BUILD_SHA` and `PUBLIC_API_URL`, then build. Grep `dist/` for the baked GA id and GlitchTip host before shipping. Clean-replace `/var/www/meetgrab.us` the staged way (skill `static-deploy-to-proxy`; memory: never delete before verifying the replacement).
- Admin: `turbo run build` refreshes `apps/admin/dist` (`VITE_API_URL`, `VITE_ADMIN_TOKEN` baked); staged replace of `/var/www/meetgrab-admin`.
- Runtime: PM2's system `node` v24.18.0 (OPS.md §0 still says Node 22). pnpm 10, turbo 2 (s013).
- Rollback: OPS §2. Check out the previous SHA → install → turbo build → restart, **then restore `BUILD_SHA`/`BUILD_RELEASED_AT`**. Every migration so far is additive, so no schema rollback. Web: rebuild the old SHA with its old env, or restore a `/var/www/meetgrab.us.bak-*` copy.

## Verify (after deploy)
- `https://api.meetgrab.us/v1/health` → `{"ok":true}`; `/v1/version` → new SHA; `grep -c 'installId: z.*\.uuid' ~/meetgrab/apps/api/dist/server.js` ≥ 1.
- Run `~/meetgrab-summary-canary.sh` (202 → poll → `state:done`). Ledger rows should show model `claude-sonnet-5` and 0 fallback (s013).
- `https://meetgrab.us/` 200, `/id/` 200, `/pricing` 200; `admin.meetgrab.us` loads.
- Logs: `~/.pm2/logs/meetgrab-api-{out,error}.log` → Fluent Bit → OpenObserve `default/app`. Look for `[summary] job failed` (s015).
- GlitchTip grabfamily: 14 `meetgrab-api`, 16 `meetgrab-web`, 15 `meetgrab-ext`. OpenPanel: shared **MeetGrab Web** project (API events too). GA4 `G-KMVL074MH2` (consent-gated).
- Kuma: #47 `meetgrab.us`, #48 API Health (keyword `"ok":true`), #49 Summary Canary (push 12 h).

## Known noise
- One transient 502 in the first seconds after `pm2 restart` (s016).
- Checkout pages 503 and PayPal webhooks 404 by design while billing is inert (README).
- The `MODE UJI COBA` banner on `/id/checkout` is the Midtrans sandbox demo, on purpose (s016).
- The canary sends no `installId`, so it never exercises usage recording (s012).
- The Opus 5 large tier rarely fires; occasional `529` from Anthropic (s013).

## Smoke test
- Safe: health, version, the canary script (one real LLM call), public page GETs, `GET /v1/pricing`.
- Don't: enable real billing or set PayPal creds without OPS §3c. Don't point the Midtrans dashboard at `/v1/billing/webhooks/midtrans` (reserved; sandbox path is `/v1/billing/sandbox/midtrans/notification`). Don't raise traffic on the OAuth token (no refresh).

## Gotchas
1. A bare `pnpm --filter @meetgrab/api build` bundled a stale `shared-types`; zod stripped `installId` and usage recording silently stopped. Always use turbo (s008, OPS §2).
2. The `/v1/summaries` 100 s block was put in the port-80 server, so HTTPS summaries still 502'd at 60 s without CORS. Edit the 443 server (s004).
3. Web `PUBLIC_*` vars aren't stored on app, so a build without them silently drops GlitchTip and analytics. It happened twice (s012, s013). Grep the built bundle.
4. OpenPanel URL needs the `/api` suffix (`…/api` → `/api/track`) (s006).
5. `ai@4` sends a default `temperature` that Claude 5 models reject with 400. Fixed by the `ai@5` upgrade, not by env (s012 → s013; memory "AI SDK v4 + Claude 5").
6. Skipping the `BUILD_SHA` stamp left `/v1/version` reporting `e396aaa` for 245 commits (OPS §2, s012).
7. `DAILY_SPEND_CAP_USD=0` now means **unlimited**; before `f9a4c6f` it meant "cap everything" (s015).
8. A bare `ssh proxy` logs in as the local user and triggered a fail2ban ban; always `root@proxy` (s010).
9. The async summary rewrite needed the live extension and the API to agree; check the extension contract before an API jump (s005).
10. The canary went false-DOWN after the async change because it expected 200. It now polls (s008).

## Open items
- **Drift (CLAUDE.md):** says "no database (in-memory per-IP rate limiting)", "Haiku 4.5 → Gemini", "`admin` not deployed". Truth: Postgres `meetgrab` since s007 (migrations through `0006`, nightly backup), primary `claude-sonnet-5` + large `claude-opus-5` + Gemini 2.5 Flash fallback (s013), admin live at `admin.meetgrab.us` (s007/s014). The registry's "check whether it's used": it is (auth, usage ledger, billing tables). The 0 connections at survey is consistent with idle pools.
- **Drift:** OPS.md says Node 22; the process runs on system Node 24.18.0.
- **Cert:** `meetgrab.us` renews about 10-26. The proxy deploy hook added 10-19 (proxy S008) reloads nginx, so check the served serial afterwards (registry §6/§10).
- Midtrans sandbox demo is still on production (`MIDTRANS_SANDBOX_ENABLED`, `…_ALLOW_ON_PRODUCTION_HOST`); turn it off when the review completes. The notification URL isn't set (s016).
- `DAILY_SPEND_CAP_USD=0` (unlimited) has no end date (s015). OAuth token has no refresh (README).
- A production Midtrans server key was pasted in plain text during development; rotate it (s016).
- `meetgrab-api` has no `max_memory_restart` and no `NODE_ENV` in its PM2 env (registry anomalies 14, 15).
- Extension on the Web Store lags `main` (v1.11.0 live vs 1.20+ at s012). Current store version not rechecked. Google OAuth consent screen still in Testing (s011).
- `BETTER_AUTH_SECRET` and `ADMIN_TOKEN` exist only in `apps/api/.env` on app, not in 1Password (s011, s014).
- 10 `.env*bak*` files in the meetgrab tree on app (registry). Old static backups `meetgrab.us.bak-*` ×2 and `meetgrab-admin.bak-*` on proxy.
- Unknown: whether the PayPal reconciliation cron in OPS §3c (04:15 daily) is installed. Billing is inert, so probably not.

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep meetgrab; ss -tlnH | grep ":8930"; git -C ~/meetgrab log -1 --format="%h %cs"; crontab -l | grep -i meetgrab'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d meetgrab -c 'select count(*) from drizzle.__drizzle_migrations' -c \"select count(*) from pg_stat_activity where datname='meetgrab'\""
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls /var/www | grep meetgrab; certbot certificates 2>/dev/null | grep -A2 "Name: meetgrab.us"; nginx -T 2>/dev/null | grep -B2 -A3 "location = /v1/summaries"'
curl -s https://api.meetgrab.us/v1/health; curl -s https://api.meetgrab.us/v1/version
```
