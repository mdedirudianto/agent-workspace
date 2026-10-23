# ytgrab — profile

**Profile version:** 2 · **Stamped:** 2026-10-23 · **Sources:** ytgrab-app-reports up to session-043 (2026-10-23), app-sysadmin session-004/005/007, registry + hosts 2026-10-19 (numa not surveyed), repo at `fc9f7a1` (`origin/main` = local `main`; prod web on `app` = `fc9f7a1`, prod API on numa/db = `71dcc62`)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
- `~/Projects/ytgrab/docs/DEPLOYMENT.md`: §1 hosts, §3 API deploy per node (rollback insurance, migrate-before-boot, acceptance grep), §4 `PROXY_*` env, §6 web deploy (detached build + asset smoke), §9.3/§10.3 limiter and latency reads. **This file owns the procedure.**
- Release guides: `docs/DEPLOY_BATCH2B_FORMAT_IDS.md` (latest), `DEPLOY_MEDIA_403_FIX.md`. Backlog: `docs/FOLLOW_UPS.md`, `FOLLOW_UPS_SCRAPER_2026-09.md`. Also `PROXY_POOL.md`, `ERROR_TRACKING.md`, `ANALYTICS.md`, `infra/canary/ytgrab-download-canary.sh`.
- Workspace: [README](../../../ytgrab-app-reports/README.md) (SHA history, open follow-ups), sessions [042](../../../ytgrab-app-reports/session-042-2026-09-20.md), [041](../../../ytgrab-app-reports/session-041-2026-09-19.md), [040](../../../ytgrab-app-reports/session-040-2026-09-18.md), [038](../../../ytgrab-app-reports/session-038-2026-09-17.md) (asset-400 incident).

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| web | app | PM2 `ytgrab-web` (devops), cwd `~/ytgrab/apps/web`, Next standalone `server.js`, `/usr/bin/node` v24, no ecosystem file | `10.0.0.5:3009` | `youtubegrab.com` (all non-`/api` paths) | cert `youtubegrab.com` (apex/api/www), nginx installer, exp 2026-11-22, reloads itself |
| api node 1 | numa `10.0.0.7` | root PM2 `ytgrab-api`, `/root/ytgrab/apps/api`, `node --env-file … dist/index.js` | `10.0.0.7:7009` | `youtubegrab.com/api/*`, LB weight 2 | — |
| api node 2 | db `10.0.0.1` | root PM2 `ytgrab-api`, `nice -n 10` | `10.0.0.1:7009` (UFW: proxy only) | LB weight 1 | — |
| PO-token provider | numa + db | root PM2 `bgutil-pot` | docs `127.0.0.1:4416`; db live `*:4416` (UFW deny) | — | — |
| vhosts | proxy | `ytgrab-web.conf` (**real file** in `sites-enabled`, identical to available on 10-19); `ytgrab-api.conf` | — | `www.` and `api.` 301 → apex | same cert |
| canaries | numa | cron `~/ytgrab-download-canary.sh` (#46, twice daily) and `--tiers` every 15 min (#50–52) | — | — | — |

- proxy: upstream `ytgrab_api` = `least_conn` numa w2 + db w1; `ytgrab_web` = app:3009. Since 2026-09-17 `/api/*` accepts only Cloudflare + private cluster, scraper UA refused, CF real-IP restored in this vhost only (registry §7). Cloudflare WAF rule blocks the scraper at the edge (s038).
- dev: `dev.youtubegrab.com` vhost on dev, `ytgrab` ×2 PM2 **stopped**; dev is at `136a4e9`/v1.1.2, far behind (README).

## Data
- Postgres `ytgrab_prod` on db, **owner `postgres`, no app role**, 669 MB. Migrations through `0012` (s041). Nightly dump on backup (284 MB, 8 kept).
- Redis **db0** on db (`REDIS_URL` has no index). Keys `rl:*` (rate limiter, TTL'd) and `video:meta:*` (cache). db0 is **shared** with seenow-workers (`bull:commerce`), pasarbesar-lpekinhub (`{pb-lpekinhub}:bull:*`) and duitkas baznas (registry §4, updated 10-19), so never FLUSHDB. 38.6k keys / 274 MB on 09-20 (s042).
- Redis-only state is losable (limiter counters, metadata cache). The proxy pool's breaker/park state is in memory per API node; the rows are in Postgres. Admin reset/refresh through the LB hits one node only (DEPLOYMENT §1).
- External: Webshare plans via `WEBSHARE_API_KEY` (auto-discovered, self-healing recycle, s015). Resend (`RESEND_API_KEY` in 4 env files on 3 hosts, s021/s023). Google OAuth (s024).

## Deploy
- Mode: pull-on-host per node, **no Docker on any host**, no CI (org Actions disabled 2026-09-20). Order: API numa → API db → web on app (batch-2b guide: the API must reach both nodes first).
- API per node: follow DEPLOYMENT §3. Key points: dist backup `/root/ytgrab-api-dist-<sha>`; migrate **before** restart (numa has no `packages/db/.env`, take `DATABASE_URL` from `apps/api/.env`); build `pnpm --filter @ytgrab/api... build` (trailing `...`); set `GIT_SHA=<sha>` in `apps/api/.env` by hand; `pm2 restart ytgrab-api && pm2 save`.
- Web: follow DEPLOYMENT §6. Detached `nohup` build into `~/ytgrab-web-build.log` with an `EXIT=` marker; `postbuild` copies `static`/`public` into standalone; restart **as soon as** `EXIT=0`; then `node scripts/smoke-web-assets.mjs https://youtubegrab.com`.
- Build-time vars: all `NEXT_PUBLIC_*` in `apps/web/.env` (API base, site URL, GA, Sentry DSN, OpenPanel, extension URLs). Runtime secrets (`DATABASE_URL`, `BETTER_AUTH_*`, `PORT`, `HOSTNAME`) are in the same file, loaded via `--env-file` (s010).
- Runtime: **Node 24 mandatory** (system `/usr/bin/node` on all three hosts, no nvm). Node 26 breaks undici `ProxyAgent`.
- Rollback: API = check out the previous SHA, restore its dist dir, reset `GIT_SHA`, restart, per node. **Roll-forward only past migration 0010** (ytgrab s022). Web = check out the previous SHA + detached rebuild + restart. Env-only switches: `RATE_LIMIT_MODE=off`, `DOWNLOAD_URL_CACHE_TTL_MS=0`, `PROXY_DOWNLOAD_KIND_ORDER`.

## Verify (after deploy)
- `GET https://youtubegrab.com/api/v1/health` → 200, check **`gitSha`** (the `version` field always reads `0.0.0`, s042).
- `/api/v1/download-check` → 204; `download?itag=140-drc` → 206; `/videos:process` → 200; site 200; asset smoke exit 0 (22 assets + image optimizer).
- Boot lines per node: `rate limiter {"mode":"enforce"}`, `resolved-url cache {ttlMs, node}`, pool counts, `api listening`.
- Logs: numa/db `pm2 logs ytgrab-api`; app `~/.pm2/logs/ytgrab-web-{out,error}.log`. OpenObserve stream `ytgrab` (Vector on app) and `app` (Fluent Bit). API nodes ship via `OPENOBSERVE_*` in `apps/api/.env`.
- GlitchTip org grabfamily: 3 `youtubegrab-web`, 4 `youtubegrab-api`, 5 `youtubegrab-ext`.
- Kuma: #13 site, #34 api (301 → up), #45 Health keyword, #46 Download Canary (push 12 h), #50/#51/#52 tier canaries (push 20 min).
- After any limiter change, watch `rate limit refused` lines, 429s, `rate_limit_decisions_total{outcome="limited"}` (s042).

## Known noise
- Health `version: 0.0.0` (s042). Python 3.10 deprecation banner in `process_events.error_detail` from db (s037).
- A handful of `rate limit would refuse`/`refused` lines from ~5 heavy clients (s042).
- About 35–38% of `download_events` are `aborted`: slow proxies plus user retries. Track ok %, not fail % (s034, s042).
- Content refusals return 422 with a `reason` and are no longer sent to GlitchTip (s042).
- `bgutil-pot` heap restarts (s034). Residential `QUOTA_EXHAUSTED` on #52 while the plan is spent (s027).
- proxy `error.log` `Connection refused 10.0.0.5:3009` around web restarts (proxy survey 10-19).

## Smoke test
- Safe: health, download-check, one small ranged download (206), `smoke-web-assets`, `/api/v1/status`.
- Don't: restart an API node without draining it at nginx first (it cuts in-flight downloads, s040). Don't run any `process_events` UPDATE without a dry run, a guarded transaction and a backup table (s042). Don't touch db0 keys except by an exact `--scan --pattern` (s036 deleted exactly 14 `video:meta:*` keys).

## Gotchas
1. turbo doesn't track `apps/web/.env`. An env-only change needs `rm -rf apps/web/.next` before the build (s003).
2. `api-client` is a dependency of **web**, so build each app with its `...` closure (s009).
3. The Next standalone server doesn't read `.env`, so the web runs with `--env-file`. Recreating the PM2 entry once dropped `PORT`/`HOSTNAME` and it bound to `0.0.0.0:3000` (s010).
4. `sites-enabled/ytgrab-web.conf` is a real file: edit that one. A `.bak` inside `sites-enabled/` loads as config ("duplicate upstream") (s010).
5. Missing standalone assets return 200 and render HTML while the site is dead. Check with the content-type smoke, not status codes (s033).
6. A foreground build over SSH hung on a dead stdout, and `/_next/static` returned 400 for 49 min. Always build detached (s038).
7. Restarting 3.5 min after the build finished left old HTML pointing at new chunks. Restart right after `EXIT=0` (s042).
8. googlevideo URLs are locked to the exit IP that resolved them, so byte fetches must use the same proxy (s011).
9. An exhausted Webshare tier still reads `status=active`. Trust the day-over-day byte delta (s034).
10. For a Kuma push monitor, `interval` must exceed the cron period plus runtime variance (s032). #46 still has zero slack.
11. The canary called `127.0.0.1:7009`, but the API binds its private IP, so #46 was never UP from 06-25 to 09-17 (s037/s038).
12. The Node 24 apt install on app bounced every PM2 app there and broke Directus `isolated-vm` (ytgrab s022 → app-sysadmin s005).
13. A saved PM2 config is not the running one: the `bgutil-pot` heap cap was configured but never loaded (s035). Confirm env values in the live process (s033 §10).
14. numa's deploy key is read-only, so repo fixes land from the Mac (s031).
15. A 2.5 GB `ytgrab-api` leak on app swap-thrashed the host and froze miaw-route. That's why the API left app and has memory caps (app-sysadmin s004).
16. Next 15.5 scans the whole `.next/standalone/apps/web/.next/cache/images` at boot (serial `readdir`+`readFile`) and every `/_next/image` request awaits it. An uncapped cache (54k entries / 1.5 GB) hung all thumbnails ~17 min after a cold reboot (s043). `images.maximumDiskCacheSize` is now 256 MiB (`fc9f7a1`); the web build recreates the cache dir. Check with `du -sh` on that dir; prune with a path-guarded `find … -mtime +7` (derived cache, no restart needed).
17. The web build is slow: ~3.7 min compile plus ~5 min "Collecting build traces" (about 10.8 min, asset gap for the whole time, s043). In a backgrounded SSH command redirect everything: a bare `date` on the pipe hung the tool call.

## Open items
- **Drift (CLAUDE.md):** says "Docker compose stack on app". Live truth (registry, s018, s042): `ytgrab-web` PM2 on app :3009; `ytgrab-api` + `bgutil-pot` on root PM2 on numa (primary) and db; Docker isn't installed on app. Fix the CLAUDE.md line.
- **Drift:** README puts `bgutil-pot` on `127.0.0.1:4416`; db listens on `*:4416` (UFW-blocked). numa not re-verified.
- **Contradiction:** DEPLOYMENT §1 says restart without `--update-env` (shell vars would override the file); s042 used `--update-env` on both nodes; ops-guard warns on it. Settle on one form.
- `ytgrab-web`: 57 restarts, hit `max_memory_restart` 500M at least 5× on 10-17/18, and has no `NODE_ENV`/`TZ` in its PM2 env (registry anomalies 1, 15).
- Vector double-ships web logs and still tails the dead `ytgrab-api-*` logs on app (anomaly 6). app still holds an unused `apps/api/.env` with a live `WEBSHARE_API_KEY` (DEPLOYMENT §1).
- `ytgrab_prod` has no app role (owner `postgres`) and had 0 connections at the 06:26 WIB survey. Confirm which role the apps connect as.
- ~~Local `main` ahead of `origin/main`~~ done in s043: pushed and deployed as `fc9f7a1` (web 1.18.1). The userscript 1.0.1 text still needs re-publishing on Greasy Fork by hand.
- Image-cache cap shipped in s043: confirm it stays ≲ 256 MiB, time one cold restart; Cloudflare doesn't cache `/_next/image` (`DYNAMIC`, decision pending).
- Carried from README: watch the `enforce` limiter; mobile 0.8.0 native build; dubbed-only videos; `curl_cffi` missing; Python 3.10 venv on db; no pm2-logrotate on numa/db; db has no tier canaries; OO alert rename check; build-time `GIT_SHA`; legacy `ytgrab-be`/`ytgrab-fe` leftovers; idle `until curl` loop on numa.
- Kuma #51 (datacenter tier) was DOWN at survey time. Recheck.

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep ytgrab; ss -tlnH | grep ":3009"; git -C ~/ytgrab log -1 --format="%h %cs %s"'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db 'pm2 ls | grep -E "ytgrab|bgutil"; ss -tlnH | grep -E ":7009|:4416"; git -C /root/ytgrab log -1 --format="%h %cs"'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -c \"select usename, count(*) from pg_stat_activity where datname='ytgrab_prod' group by 1\"; redis-cli CLIENT LIST | grep -c name=ytgrab-rate-limit"
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'nginx -T 2>/dev/null | grep -A4 "upstream ytgrab_api"; certbot certificates 2>/dev/null | grep -A2 "Name: youtubegrab.com"'
curl -s https://youtubegrab.com/api/v1/health | grep -o '"gitSha":"[^"]*"'
# numa needs per-session approval: ssh -o BatchMode=yes root@numa 'pm2 ls; ss -tlnH | grep -E ":7009|:4416"'
```
