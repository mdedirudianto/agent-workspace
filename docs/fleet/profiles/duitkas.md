# duitkas — profile

**Profile version:** 2 · **Stamped:** 2026-10-20 · **Sources:** duitkas-app-reports up to session-003 (2026-06-17), app-sysadmin session-001, registry + hosts 2026-10-19, repo `biji-dev/miaw-flow` at `b3b1c57` (= `origin/main` = prod; the local checkout is on `feat/multi-tenant-platform` `fa15dc5`)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
- Repo `~/Projects/miaw/miaw-flow`: `docs/Architecture.md`, `docs/DuitKas-API.md`, `docs/Message-Flow-Reference.md`, `docs/CatatKas-Setup-Guide.md` (local Docker dev only), `ecosystem.config.cjs`, `CLAUDE.md`. **The repo has no production runbook.**
- The production procedures are in the workspace: [README](../../../duitkas-app-reports/README.md) ("Adding a new client"), [session-002](../../../duitkas-app-reports/session-002-2026-06-11.md) (new instance), [session-003](../../../duitkas-app-reports/session-003-2026-06-17.md) (redeploy), [session-001](../../../duitkas-app-reports/session-001-2026-06-11.md) (rename + private bind).

## Footprint
Multi-tenant **by instance**: one folder, PM2 pair, DB, Redis db and WhatsApp pairing per client.

| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| baznas api (Fastify + WhatsApp + Socket.IO) | app | PM2 `miaw-api-baznas`, `~/miaw-flow-baznas/apps/api`, `dist/index.js`, node v24.18.0 | `10.0.0.5:7007` | `baznas.duitkas.biji.uk` `/socket.io/`, `/health` | cert `baznas.duitkas.biji.uk`, nginx installer, exp 2027-01-07 |
| baznas web (Next.js) | app | PM2 `miaw-web-baznas` (pnpm), `apps/web` | `10.0.0.5:7008` | same host, `/` | same |
| lpekin api | app | PM2 `miaw-api-lpekin`, `~/miaw-flow-lpekin/apps/api` | `10.0.0.5:7018` | `lpekin.duitkas.biji.uk` `/socket.io/`, `/health` | cert `lpekin.duitkas.biji.uk`, nginx, exp 2027-01-06 |
| lpekin web | app | PM2 `miaw-web-lpekin` | `10.0.0.5:7019` | same, `/` | same |

- proxy: one path-routed vhost per client (`<client>.duitkas.biji.uk.conf`). WebSocket upgrade headers; `/socket.io/` has `proxy_read_timeout 86400`. Port 80 returns 404 (proxy survey).
- DNS: `*.duitkas.biji.uk` must stay **grey-cloud** (two-level name, Universal SSL doesn't cover it).
- Logs: `~/miaw-flow-<client>/logs/{api,web}-out.log`. **Not shipped** to OpenObserve and **not rotated** (registry §9, app anomaly 5).
- Monitoring: no GlitchTip project, no Kuma monitor (monitor survey: coverage gap).

## Data
| Client | Postgres (owner `miaw`) | Redis (db on `10.0.0.1`) | `REDIS_KEY_PREFIX` | WhatsApp instance | Session dir |
|---|---|---|---|---|---|
| baznas | `miawflow_baznas` (8.3 MB) | **db0** (shared with seenow, lpekinhub, ytgrab) | `baznas:` | `catatkas-bot` (paired) | literal `apps/api/~/data/sessions/catatkas-bot` |
| lpekin | `miawflow_lpekin` (8.0 MB) | db5 (2 keys on 10-19) | `lpekin:` | `lpekin-bot` (pairing never confirmed) | `./data/sessions` |

- Tables: organizations, users, transactions, conversation_logs (2 drizzle migrations, s002). Both DBs had 0 connections at the 06:26 WIB survey. Nightly dumps on backup; `pg/miawflow` there is an empty leftover from the pre-rename DB.
- The role `miaw` also owns `miaw_route`, so one credential spans two products.
- **Not in any backup:** the WhatsApp session directories on app. Losing them means re-scanning the QR. Redis isn't backed up either (cache, rate limits, sessions; lazily rebuilt).
- External: DuitKas API (`DUITKAS_API_KEY` per client, base URL hard-coded to `/api/v1/baznas` for both, s003), Gemini `gemini-2.5-flash` (`GOOGLE_API_KEY`), Qwen fallback.

## Deploy
- Mode: pull-on-host per instance, PM2 under devops. Deploy `main` only (`b3b1c57` = v0.4.1 is live on both).
- **Three `.env` files per instance**: root, `apps/api/.env` (overrides root for the API), `apps/web/.env` (read by `next build`/`next start`). Edit every one that holds the key (s001).
- API-only release: `git pull --ff-only` (the locally modified `ecosystem.config.cjs` with per-client PM2 names survives an ff pull) → `pnpm install` → `pnpm -F @miaw-flow/api build` → `pm2 restart miaw-api-<client>` → `pm2 save` (s003).
- Web: `NEXT_PUBLIC_API_URL` is baked at build time, so after a URL change run `rm -rf apps/web/.next` and `pnpm -F @miaw-flow/web build` (s001).
- Migrations: `pnpm -F @miaw-flow/api db:migrate` with `DATABASE_URL` **exported** (drizzle reads `process.env` only, else it hits the localhost default) (s002). ops-guard blocks drizzle over SSH unless you add the override marker.
- New client: README "Adding a new client". Take ports and the Redis db from the registry (§2: next free app port is 3180; §4: next free Redis db is **12**), not from the June notes.
- Runtime: system Node 24 via PM2 `node`; built originally under Node 22 (June), stable since the 09-30 resurrect.
- Rollback: `git checkout <prev>` + rebuild + restart per instance; `.env.bak-v041` / `.bak-prebaznas` copies exist (s003, s001).

## Verify (after deploy)
- `https://<client>.duitkas.biji.uk/health` → 200 `{status:ok, redis:connected, whatsapp:connected}` (lpekin reads `connecting` until paired).
- `/socket.io/?EIO=4&transport=polling` returns a sid; `/` → 200 `X-Powered-By: Next.js`.
- API log lines: `keyPrefix:"<client>:" Redis connected`, PostgreSQL repos init with the right DB, `WhatsApp connected and ready!` with no QR (s001, s003).
- `ss -tlnH` shows 7007/7008/7018/7019 on `10.0.0.5` only.

## Known noise
- `QR code received` broadcasting on lpekin while it's unpaired (s002).
- Prefixed Redis keys appear only after the first message (s003).
- The root `miaw-core` symlink is dangling; the real dependency is `node_modules/miaw-core` (s001).
- The systemd unit `actions.runner.biji-dev-miaw-flow.app` (failed since 08-02) was an old GitHub runner, not the app; disabled 2026-10-20 ([backup S006](../../backup-sysadmin-reports/session-006-2026-10-20.md)).

## Smoke test
- Safe: `/health`, socket.io handshake, page GET, log tail.
- Don't: run `db:seed` (it clears data and inserts samples, s002). Don't "fix" baznas's literal-`~` `MIAW_SESSION_PATH` without moving the session dir (it forces a QR re-scan, s001). Don't send test WhatsApp messages through a client's bot without the client's OK. Never FLUSHDB db0 (shared with seenow-workers, pasarbesar-lpekinhub and ytgrab).

## Gotchas
1. The API loads root `.env` first and then `apps/api/.env`, so the later file wins. All three files had to change for the rename (s001).
2. `MIAW_SESSION_PATH=~/data/sessions` was never tilde-expanded, so baznas's session lives in a directory literally named `~` (s001).
3. Cloudflare's "Always Use HTTPS" blocked HTTP-01, and Universal SSL doesn't cover `*.duitkas.biji.uk`. Keep it grey-cloud (s001).
4. Drizzle `db:migrate` ignores `.env` unless `DATABASE_URL` is exported (s002).
5. `/api/v1/lpekin` categories 404; both tenants use `/baznas`, whose category IDs are global. The static fallback map is stale (s003).
6. Before session-001 the ports were bound to `0.0.0.0` and open to the internet; the UFW `7007:7008` rule that allowed it is still there (app-sysadmin s001, registry anomaly 3).
7. `miaw-web` had 262 restarts in the original audit (app-sysadmin s001 H1); its cause was never written down.

## Open items
- **lpekin WhatsApp pairing** has been open since 2026-06-11 (s002). `miaw-api-lpekin` restarted once on 10-16. Check `/health`.
- **Registry ambiguity:** db0's sampled prefixes on 10-19 don't include `baznas:`; the registry lists baznas there "per docs". Confirm baznas's `REDIS_URL` db and key count.
- Logs outside the Fluent Bit glob and outside pm2-logrotate (registry anomaly 5).
- No Kuma monitor for `baznas.duitkas.biji.uk` or lpekin; no GlitchTip project.
- Remove the stale UFW `7007:7008/tcp` rule on app (anomaly 3) and the failed GitHub runner unit (anomaly 16).
- Delete the `*.bak-prebaznas` / `.bak-v041` env copies (9 in total on 10-19) once stable (README).
- The unmerged `feat/multi-tenant-platform` branch may replace the per-instance model. Not deployed; ask before assuming.
- End-to-end transaction check (category from the API, `category_id` in the POST) never done (s003).
- CLAUDE.md lists only baznas. Add the lpekin instance (`lpekin.duitkas.biji.uk`, 7018/7019, `miawflow_lpekin`, Redis db5).

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep miaw-; ss -tlnH | grep -E ":70(07|08|18|19)"; for c in baznas lpekin; do git -C ~/miaw-flow-$c log -1 --format="$c %h %cs"; done'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db 'redis-cli -n 0 --scan --pattern "baznas:*" --count 1000 | wc -l; redis-cli -n 5 --scan --pattern "lpekin:*" | wc -l; sudo -u postgres psql -XAt -c "select datname, pg_get_userbyid(datdba) from pg_database where datname like '"'"'miaw%'"'"'"'
for c in baznas lpekin; do curl -s https://$c.duitkas.biji.uk/health; echo; done
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'certbot certificates 2>/dev/null | grep -A2 duitkas'
```
