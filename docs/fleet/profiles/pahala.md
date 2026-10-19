# pahala — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** pahala-app-reports up to session-001 (2026-10-18), registry 2026-10-19, repo docs at `origin/main` `8d7458a` (local checkout `d72d722` on `feature/image-upload`, see Open items)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| Doc | Path / note |
|---|---|
| Deploy guide | `~/Projects/pahala/docs/deployment-guide.md`: written for a DigitalOcean droplet (`/home/pahala`, `api.pahala.co`, local PG). **Not our topology**; use it for app facts only |
| Deploy script | `~/Projects/pahala/scripts/deploy.sh`: hardcodes `/home/pahala/pahala`, `localhost:3000`, `ecosystem.config.js`. **Do not run on `app`** |
| Payments | `docs/midtrans-setup-guide.md` (on main); `docs/xendit-setup-guide.md` (branch only, see Open items) |
| Ops / admin | `docs/troubleshooting-guide.md`, `docs/admin-user-guide.md`, `docs/whatsapp-flows-testing-guide.md` |
| Workspace | [session-001](../../../pahala-app-reports/session-001-2026-10-18.md) is the as-built record and the de-facto runbook (follow-up 12 = update steps) |

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| Web + API (Next 16, `next start`) | app | PM2 `pahala` (fork ×1), `/home/devops/pahala`, server-local untracked `ecosystem.config.cjs` | `10.0.0.5:3170` (args `-H 10.0.0.5 -p 3170`) | `pahala.co` | LE `pahala.co` (apex+www), HTTP-01 webroot, expires 2027-01-16, **no auto reload** |
| Redirect | proxy | vhost `pahala.co.conf` | — | `www.pahala.co` and all :80 → 301 `https://pahala.co` | same cert |
| Staging (not prod) | dev | PM2 `pahala` under `deploy` | `127.0.0.1:7005` | `dev.pahala.co` (demo ribbon, local PG 14 `pahala`) | dev nginx |

- Cloudflare zone `pahala.co`: orange, Full (strict), **Always Use HTTPS off**, Bot Fight Mode off (S001).
- Vhost: CF real-IP restore (22 ranges, `CF-Connecting-IP`, per vhost), `limit_req_zone pahala_webhook` 300 r/min burst 100 on `/api/webhook/`, `client_max_body_size 10M` (S001).
- Runtime: nvm Node v22.22.0 (not system v24), `NODE_ENV=production`, `TZ=Asia/Jakarta`, `max_memory_restart 700M`, `merge_logs` (registry, S001).

## Data
| Store | Detail |
|---|---|
| Postgres | `db` 16.9, DB `pahala`, owner role `pahala` (plain, non-superuser). Prisma 7, 2 migrations (`20260126072547_init`, `20260128062311_add_campaign_slug`), 7 public tables (S001) |
| Redis | **none** |
| Object storage | DO Spaces (`DO_SPACES_*` in `.env`); code on `main` does not read them yet (branch `feature/image-upload` does) |
| Backups | `backup` Tier-2 auto-discovery: `/root/backups/pg/pahala/`, 1 dump at 10-18 19:09 (registry). Weekly `verify.sh` Tue 21:00 has not run on it yet |
| Process-local state | none that matters (no queues) |

`.env` key names (22, registry): `DATABASE_URL AUTH_SECRET AUTH_URL AUTH_SESSION_MAX_AGE NEXT_PUBLIC_APP_URL NEXT_PUBLIC_SITE_URL NEXT_PUBLIC_WHATSAPP_NUMBER MIDTRANS_IS_SANDBOX MIDTRANS_CLIENT_KEY MIDTRANS_SERVER_KEY PORT TZ WHATSAPP_PHONE_NUMBER_ID WHATSAPP_BUSINESS_ACCOUNT_ID WHATSAPP_ACCESS_TOKEN WHATSAPP_VERIFY_TOKEN WHATSAPP_APP_SECRET DO_SPACES_KEY DO_SPACES_SECRET DO_SPACES_BUCKET DO_SPACES_REGION DO_SPACES_CDN_ENDPOINT`. No `NEXT_PUBLIC_DEMO_MODE`, no `NODE_ENV` line (PM2 sets it).

## Deploy
- **Mode:** PM2 pull-on-host. `git fetch && git checkout <sha>` (detached HEAD, deploy from `main`, pin the SHA), `npm ci`, `npx prisma migrate deploy`, `npm run build`, `pm2 restart pahala` (S001 follow-up 12).
- **Order:** **migrate before build**: `/sitemap.xml` prerenders and queries `campaigns` at build time (S001).
- **Node:** nvm v22.22.0 first on `PATH` for `npm ci`/build; the PM2 entry is pinned to the nvm interpreter.
- **Build-time vars:** `NEXT_PUBLIC_APP_URL`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_WHATSAPP_NUMBER` (and `NEXT_PUBLIC_DEMO_MODE`, must stay unset). Changing them needs a rebuild.
- **Restart:** `.env`-only change → `pm2 restart pahala --update-env` (S001 follow-up 7). Never `pm2 start` the repo's `ecosystem.config.js`.
- **Rollback:** not rehearsed. Code: `git checkout <previous sha>`, rebuild, restart. Schema: no down migrations; take `pg_dump -Fc pahala` before any release with migrations (nightly dump can be ~1 day old).

## Verify (after deploy)
| Check | Expected |
|---|---|
| `https://pahala.co/api/health` | 200 `{"status":"ok",…,"database":"connected"}`; non-200 when the DB is down |
| `/`, `/campaigns`, `/transparency`, `/login`, `/robots.txt`, `/sitemap.xml`, `/api/public` | 200 |
| `https://www.pahala.co/`, `http://pahala.co/` | 301 → `https://pahala.co/…` |
| `/admin/dashboard` unauthenticated | 307 → `/login?callbackUrl=…`; `/api/admin/stats` → 401 |
| `POST /api/webhook/midtrans` bad signature | 401 `Invalid signature` |
| `GET /api/webhook/whatsapp` wrong verify token | 403 |
| HTML | 0 "demo" ribbon hits, 0 `dev.pahala.co`; sitemap `<loc>` on `https://pahala.co` |
| Logs | `~/.pm2/logs/pahala-out.log` / `-error.log` (fluent-bit → OpenObserve stream `app`) |
| GlitchTip / Kuma / OpenPanel | **none** (registry: no Kuma monitor for pahala.co; no GlitchTip project) |

## Known noise
- One Next boot warning: `next start` with `output: 'standalone'` in `next.config.ts` (S001).
- `/api/health` reports `"version":"1.0.0"` (fallback when `npm_package_version` is unset), not the package's 0.8.0 (S001 smoke).
- WhatsApp webhook POST with a wrong-length signature → **500** (`ERR_CRYPTO_TIMING_SAFE_EQUAL_LENGTH`), request not processed (S001).
- PM2 log times are CEST (WIB − 5 h) while the app runs `TZ=Asia/Jakarta` (S001).
- `db` shows 0 connections to `pahala` when idle (registry): it connects on demand.
- First ACME probe right after an nginx reload can 404 once, then OK (S001).

## Smoke test
- Safe: everything in Verify, plus admin login through the real Auth.js flow (wrong password → `/login?error=…`; right → 302 dashboard) and a read-only Midtrans status lookup of a non-existent order (404 = key authenticates) (S001).
- **Do not:** POST a donation/payment, create a real Midtrans transaction, send a WhatsApp message, or run `prisma db seed` (creates demo orgs/campaigns and a well-known demo admin login) (S001).

## Gotchas
1. Migrate before build, or the build fails on the `/sitemap.xml` prerender (S001).
2. Midtrans server key must be stored in its raw `SB-Mid-server-…` form. dev's `.env` copy is base64-wrapped and gets 401; don't copy it verbatim (S001).
3. Two ecosystem files on `app`: the repo's tracked `ecosystem.config.js` targets `/home/pahala` and is unused; the live one is the untracked `ecosystem.config.cjs` (S001; registry flags the ambiguity).
4. `NEXT_PUBLIC_*` are baked at build: the sandbox → production switch of Midtrans is an `.env` + restart, but any public-var change is a rebuild (S001).
5. HTTP-01 webroot cert, no CF token for the zone: a new subdomain means re-issue, and "Always Use HTTPS" must stay off or renewal breaks (S001).
6. nginx reload after the `pahala.co` renewal is handled by the proxy deploy hook since 2026-10-19 (proxy S008).
7. Secrets streamed from dev over SSH stdin, never printed; don't `grep ^VAR=` a secret on `app` (S001, memory "psql on app: never echo the DB URL").
8. Cloudflare page loads from the owner's workstation took 10–14 s in S001: workstation routing, not the site. Test from `app` before calling it an outage (S001).

## Open items
- **Repo drift, next deploy is not a routine update:** local branches `feature/xendit-qris`, `feature/web-donation` (pushed) and `feature/image-upload` (local only, dirty) are 13 commits ahead of `main`. They **remove Midtrans for Xendit QRIS**, add 2 migrations (`20261019000000_xendit_gateway` renames `midtrans_txn_id` → `gateway_txn_id`; `20261019010000_web_donation`), new env (`XENDIT_SECRET_KEY`, `XENDIT_CALLBACK_TOKEN`, `CRON_SECRET`, `WHATSAPP_CONFIRMATION_TEMPLATE*`), a per-minute expiry cron calling `/api/cron/expire-donations`, and an nginx `checkout_limit` for `POST /api/public/donations`. Needs a release-preflight once it lands on `main`; the Midtrans items below may become moot.
- Owner: register webhook URLs (`/api/webhook/midtrans`, `/api/webhook/whatsapp`, `/api/flows/data-exchange` if Flows) (S001 #1).
- Owner: Uptime Kuma monitor on `/api/health`, GlitchTip project if wanted (S001 #2; registry confirms none yet).
- Owner: collect the initial admin password from `~/pahala-admin-initial.txt` on `app` (devops, 0600), store it in Vaultwarden, **delete the file** (S001 #3).
- Dev: fix `verifyWebhookSignature` length check; fix dev's base64 Midtrans key; decide `standalone` vs `next start` (S001 #4, #6).
- Owner: privacy/terms pages before Midtrans/Meta review; MX/SPF/DKIM/DMARC (S001 #5, #8).
- Go-live: `MIDTRANS_IS_SANDBOX=false` + 3 keys, restart (S001 #7), unless Xendit replaces Midtrans first.
- Check the first `verify.sh` result for `pahala` (Tue 2026-10-20 21:00 WIB) (S001 #9; the dump itself exists per registry).
- Remove `~/p3-build.sh`, `~/p3b-build.sh`, `~/pahala-build.log`, `~/pahala-build2.log` on `app` (S001 #10).
- Repo doc drift: `deployment-guide.md` names `WHATSAPP_WEBHOOK_VERIFY_TOKEN`; the code reads `WHATSAPP_VERIFY_TOKEN`.
- No registry/report contradictions found beyond the ecosystem-file ambiguity (Gotcha 3).

## Verify live
```bash
# app: process, bind, checkout, env names only
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep -w pahala; ss -tlnH | grep ":3170 "; git -C ~/pahala rev-parse --short HEAD; cut -d= -f1 ~/pahala/.env | tr "\n" " "; ls ~/pahala-admin-initial.txt 2>&1'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'curl -s http://10.0.0.5:3170/api/health; echo'
# public
curl -s -o /dev/null -w "%{http_code}\n" https://pahala.co/api/health; curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://www.pahala.co/
# proxy: vhost + cert
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -l /etc/nginx/sites-enabled/pahala.co.conf; certbot certificates --cert-name pahala.co 2>/dev/null | grep -E "Domains|Expiry"'
# db: DB, owner, migrations applied
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -c \"select datname, pg_get_userbyid(datdba) from pg_database where datname='pahala'\"; sudo -u postgres psql -XAt -d pahala -c 'select count(*) from _prisma_migrations where finished_at is not null'"
# backup: dumps
ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup 'ls -l /root/backups/pg/pahala/ | tail -3'
```
