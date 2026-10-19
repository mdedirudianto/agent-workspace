# seenow — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** seenow-app-reports up to session-005 (2026-06-24), registry 2026-10-19, repo docs at `790075f` (local branch `feat/mobile-learner-app`; `origin/main` `303ce88`, 15 commits past prod `1895e1e`; local refs, not fetched)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| What | Where (`~/Projects/seenow/…`) |
|---|---|
| Production runbook (Docker + `seenow.id` topology, **not** what prod runs; use §9 rollout, §10 smoke list, §11 rollback as the checklist) | `docs/Production_Deploy.md` |
| Security / RLS baseline | `docs/Seenow_Security_Baseline.md`, `docs/Seenow_Technical_Architecture.md` (TA §8 RLS, §11 PM2) |
| AI auth | `docs/CLAUDE-OAUTH-GUIDE.md` |
| Repo PM2 / nginx samples (api + workers only; prod's config differs) | `deploy/pm2.ecosystem.cjs`, `deploy/nginx/`, `deploy/render-custom-domains.ts` |
| Workspace reports | [session-003](../../../seenow-app-reports/session-003-2026-06-16.md) (prod deploy), [004](../../../seenow-app-reports/session-004-2026-06-17.md) (private bind + tenant CORS), [005](../../../seenow-app-reports/session-005-2026-06-24.md) (dev reseed), README "Gotchas" |
| Bare-metal adaptation | lives only in the workspace reports; the repo has no bare-metal runbook |

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| api (Bun/Hono; WS `/v1/ws`, tutor SSE) | app | PM2 `seenow-api`, cwd `~/seenow` | 10.0.0.5:4900 (`API_HOST`) | api.seenow.ac | `seenow.ac` |
| workers (Bun, BullMQ) | app | PM2 `seenow-workers`, cwd `~/seenow` | — | — | — |
| web-public (Next, `next start`) | app | PM2 `seenow-web-public`, cwd `~/seenow/apps/web-public` | 10.0.0.5:4901 | seenow.ac; `www` → 301 apex | `seenow.ac` |
| learner / teacher / b2b / admin SPAs (Vite) | proxy | `/var/www/seenow/web-{learner,teacher,b2b,admin}` (last published 2026-06-16) | — | learner./teacher./b2b./admin.seenow.ac | `seenow.ac` |
| tenant white-label | proxy | `~^(?<tenant>[^.]+)\.seenow\.ac$` → web-learner + `X-Seenow-Tenant` | — | `<tenant>.seenow.ac` | **currently broken, see Open items** |
| nginx | proxy | `sites-available/seenow.conf` (symlinked) | — | — | — |

- PM2 under `devops`, ecosystem `~/seenow.config.cjs` (outside the repo; must be named `*.config.cjs`, S001). `NODE_ENV=production`. Max mem 700M api, 500M workers/web.
- Cert `seenow.ac` (apex + `*.seenow.ac`), dns-cloudflare, `/etc/letsencrypt/cloudflare-seenow.ini`, exp 2027-01-13, reloaded by the proxy deploy hook (since 2026-10-19, proxy S008). CF orange, **Full (strict)** (confirmed S004).
- Restart baseline 10-19: all three ↺0 since the PM2 daemon restart 2026-09-30. Code on app `1895e1e` (2026-06-17); only `apps/web-public/.env.production` untracked.

## Data
| Store | Facts |
|---|---|
| Postgres `seenow` on db | 11 MB. Owner/migration role `seenow` (**CREATEDB, CREATEROLE, BYPASSRLS**, not superuser) via `DATABASE_URL`; runtime role `seenow_app` (non-superuser, RLS binds) via `APP_DATABASE_URL`, password from `SEENOW_APP_DB_PASSWORD`. 2 conns as `seenow_app` on 10-19. 57 tables, 16 migrations (0000–0015). `vector` 0.8.2 created as `postgres` (untrusted) |
| Redis | `.env` says db **7**, but **seenow-workers actually use db 0** (11 connections, verified 10-19 by client address). Queue `bull:commerce` holds 35,839 retained completed `commerce-reconcile` jobs (about +288/day, no `removeOnComplete`). seenow-api holds no Redis connection |
| Object storage | deferred; `S3_*` set but unused by the code (S001, S003) |
| AI | Anthropic via personal Claude OAuth (`ANTHROPIC_AUTH_MODE`, `ANTHROPIC_AUTH_TOKEN`); `EVAL_MODEL`; repo pins `ai@^4` |
| Backups | backup host daily `pg/seenow` (254 K, 10-18). No prod seed exists to lose; real content is in PG only |

## Deploy
- **Mode:** PM2 pull-on-host from `main` with a pinned SHA (`git fetch`, check `origin/main` = analysed SHA, `git merge --ff-only`), then `bun install --frozen-lockfile` (Bun at `~/.bun/bin/bun`, also on PATH via the S062 `/usr/local/bin` symlink).
- **Migrate before restart, from the repo root:** `bun run apps/api/src/db/migrate.ts` with the prod `.env` (never via `--filter` / `bun db:migrate`, G1). Then the RLS gate `bun run verify:g3:deploy` must print 27/27 (S001, S003, S005).
- **API/workers:** run from source on Bun, so `git pull` + `pm2 restart seenow-api seenow-workers` (S004). Bun reads `.env` at start, so a plain restart picks up `.env` changes.
- **Build-time env:** `apps/web-public/.env.production` and `apps/web-{learner,teacher,b2b,admin}/.env` bake the API and portal URLs; the root `.env` is not forwarded by turbo (G2). Build with `bun run build` (turbo, 7 tasks).
- **web-public:** rebuild, then `pm2 restart seenow-web-public` (`next start -H 10.0.0.5 -p 4901`).
- **SPAs:** build on app, relay app → Mac → proxy `/var/www/seenow/web-*` (one binary stream per ssh call, stage, assert `index.html`, backup, `rsync -a --delete`). Skill `static-deploy-to-proxy`.
- **Rollback:** `git checkout <prev>` + rebuild + `pm2 restart`; migrations are additive; DB fallback = a `pg_dump` taken before the deploy (repo §11: never hand-edit migration history). Keep the SPA backup dir until verified.

## Verify (after deploy)
| Check | Expect |
|---|---|
| `https://api.seenow.ac/healthz` / `/readyz` (or `http://10.0.0.5:4900/…` on app) | 200, `{ready:true}` |
| seenow.ac / www.seenow.ac | 200 / 301 → apex |
| learner./teacher./b2b./admin.seenow.ac | 200 |
| `GET /v1/catalog/courses` | 200 (`[]` on an unseeded prod) |
| `POST /api/auth/sign-in/email` bad creds, `Origin: https://learner.seenow.ac` | 401 + `access-control-allow-origin` echoed (S003) |
| Same from a tenant origin | 400, not 403 (Better Auth trust, S004) |
| Logs | `~/.pm2/logs/seenow-{api,workers,web-public}-{out,error}.log` (CEST), shipped to OpenObserve stream `app` by Fluent Bit |
| Errors / analytics / uptime | **none wired**: no GlitchTip project, no Kuma monitor, OpenPanel not recorded; `OTEL_EXPORTER_OTLP_ENDPOINT` is empty |

## Known noise
- Minified bundles still contain `localhost:4900` strings: dead `?? "…"` fallbacks, the baked value is the real URL (S001).
- `/v1/catalog/courses` returns `[]` in prod: no seed by design (S003).

## Smoke test
- **Safe:** the Verify table; a bad-credential sign-in from a named portal and from one tenant origin; repo `docs/Production_Deploy.md` §10 items that don't write.
- **Reversible, only with approval:** a disposable learner sign-up + free enrolment, deleted by exact ID afterwards (memory `feedback_never_delete_real_data`). Not done in any session yet.
- **Never in prod:** `scripts/reset-db.ts`, `bun db:reset`, `bun seed:content` / `seed:users` (seeds are not idempotent and create QA accounts with a known password), or migrate with `NODE_ENV` overridden.

## Gotchas
1. `bun db:migrate` runs via `--filter`, so cwd is `apps/api`, Bun loads no `.env`, and `DATABASE_URL` falls back to a default: auth fails. Run `bun run apps/api/src/db/migrate.ts` from the repo root (S001, S005).
2. Next/Vite read env from their own app dir; turbo strict env doesn't forward `NEXT_PUBLIC_*`/`VITE_*` from root (S001).
3. PM2 treats only `*.config.cjs` as an ecosystem; any other name runs as a single script (S001).
4. Migrate under the prod env: under a non-production `NODE_ENV` with `SEENOW_APP_DB_PASSWORD` unset, `rls.sql` resets `seenow_app` to a dev password and breaks `APP_DATABASE_URL` (S005).
5. `drop schema public cascade` also drops `vector`; recreate it as `postgres` before migrating (S005).
6. Seeds are not idempotent: a reseed is wipe-first (S005, dev only).
7. Hono CORS and Better Auth `trustedOrigins` are separate: tenant sign-in 403'd beneath CORS until both read `TENANT_ROOT_DOMAIN` (S004).
8. The Bun API binds `0.0.0.0` unless `API_HOST` is set (S003, S004).
9. The `seenow.ac` CF token was not in the old dev token's scope; it lives in its own file on proxy and dev (S001, S003).
10. `ai@4` forces `temperature`, which Claude 5-series models reject with a 400: switching `EVAL_MODEL` to a 5-series model needs an SDK upgrade, not an env change (memory `reference_ai_sdk_v4_claude5_temperature`).

## Open items
- **Registry vs S003 — tenant routing:** on 10-19 `foo.seenow.ac` got a 403 with CN=eventopia.my, because `eventopia-custom-domains.conf` (`~^.+$`, created 2026-07-14) is tested before `seenow.conf`'s tenant regex. S003's `acme-corp.seenow.ac` 200 no longer holds. Under Full (strict) a tenant request through Cloudflare likely fails on the cert name (unverified).
- **Redis db mismatch (verified 10-19):** `REDIS_URL` ends `/7`, but the workers connect to db 0, the db shared with pasarbesar, ytgrab and duitkas. The BullMQ connection probably drops the db index (it may be built from host/port only); check the workers' connection code. Also add `removeOnComplete` to the repeat job. Moving to db 7 orphans the db 0 keys: clean them up by exact pattern `bull:commerce:*` only after confirming nothing else uses that queue name. Needs an owner decision and a code change.
- **Registry vs reports — ecosystem:** the app survey lists seenow with "no ecosystem file" (it checked repo dirs); reports place it at `~/seenow.config.cjs`. Confirm with `pm2 describe`.
- Prod is `1895e1e`; `origin/main` `303ce88` adds 15 commits: 3 IDOR security fixes (commerce, messaging, scheduling), an authoring validation fix and "make the live Anthropic provider path actually work end-to-end". No migration in that range. The AI tutor path has never been exercised in prod (S001, S005).
- Personal OAuth token serves prod AI; dedicated `ANTHROPIC_API_KEY` deferred (S003, S004).
- `seenow` role is broader than other owner roles (CREATEDB + CREATEROLE + BYPASSRLS; registry db §16).
- No GlitchTip, Kuma or OTel for prod (monitor survey, S001).
- Dev (`*.dev.seenow.ac`) PM2 processes are stopped (registry §3); leave them stopped unless asked.
- `seenow.ac` cert renews ~2026-12-14. The proxy deploy hook (10-19) reloads nginx, so check the served serial afterwards.

## Verify live
```bash
APP='ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app'
$APP 'pm2 ls | grep seenow; pm2 describe seenow-api | grep -E "script path|exec cwd|interpreter"'
$APP 'ls -l ~/seenow.config.cjs; ss -tlnH | grep -E ":(4900|4901) "; git -C ~/seenow log -1 --format="%h %cd" --date=short'
$APP 'grep -oE "^[A-Z_]+=" ~/seenow/.env | sort | tr -d = | tr "\n" " "; curl -s -o /dev/null -w "%{http_code}\n" http://10.0.0.5:4900/readyz'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db 'redis-cli INFO keyspace; redis-cli CLIENT LIST | grep -c "db=7 "'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d seenow -c 'select count(*) from drizzle.__drizzle_migrations'"
curl -s -o /dev/null -w "%{http_code} %{ssl_verify_result}\n" https://foo.seenow.ac/   # tenant routing check
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -ld /var/www/seenow/web-*; certbot certificates 2>/dev/null | grep -A2 "Name: seenow"'
```
