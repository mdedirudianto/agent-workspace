# avilia — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** avilia-app-reports up to session-002 (2026-09-19), registry 2026-10-19, repo docs at `ce4fdc3` (= `origin/main` = deployed)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| Doc | Path (in `~/Projects/avilia/`) | Use |
|---|---|---|
| Prod runbook | `docs/operations/deployment.md` | **Not our infra** (`127.0.0.1:4030`, local PG `avilia_prod`, `/var/www/app.avilia.id`). App facts only (S001) |
| Agent deploy contract | `docs/agents/deploying-to-prod.md` | same single-VPS trap (S001) |
| Staging | `docs/operations/deployment-staging.md` | `*.dev.avilia.id` on `dev` |
| Integration contract | `docs/operations/service-integration-spec.md`, `hoteru-integration-plan-v2.md` | HMAC events, affiliate-sync |
| Hoteru side | `~/Projects/hoteru/docs/avilia-integration.md`; `deployment-prod-avilia.md` is marked UNVERIFIED and targets the old single VPS | |
| Workspace | [S001](../../../avilia-app-reports/session-001-2026-09-19.md) (as-built), [S002](../../../avilia-app-reports/session-002-2026-09-19.md) (Hoteru wiring), [hoteru S019](../../../hoteru-app-reports/session-019-2026-10-09.md) (reconciliation endpoint) | |

`ecosystem.config.cjs` in the repo (`avilia-backend`, `127.0.0.1:3001`) is **not** what runs.

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| API (Fastify 5, `dist/app.js`) | app | PM2 `avilia-api` (fork, cwd `~/avilia/apps/backend`, `--max-memory-restart 500M --time`), `/home/devops/avilia` @ `ce4fdc3` on `main` | `10.0.0.5:3140` (`HOST`/`PORT` in `apps/backend/.env`) | `api.avilia.id` | LE `avilia.id` (apex, `www`, `app`, `api`), HTTP-01 webroot, expires 2026-12-18, **no auto reload** |
| Portal SPA (Vite/React 19) | proxy | static `/var/www/avilia-app` + `/api/` proxied to `10.0.0.5:3140` | — | `app.avilia.id` | same cert |
| Holding page | proxy | static `/var/www/avilia.id` ("Segera Hadir") | — | `avilia.id`, `www` | same cert |
| Staging | dev | PM2 `avilia-api` under `deploy`, `releases/avilia-fix-20261007` | `127.0.0.1:4030` | `*.dev.avilia.id` | dev nginx |

- vhost `avilia.id.conf` (port 80: ACME webroot + 301). Cloudflare orange, Full (strict), "Always Use HTTPS" off, **no CF token for this zone**.
- Runtime: system Node v24.18.0 (PM2 `node`); no `NODE_ENV` in PM2 env, it comes from `.env` (registry).
- Callers: `hoteru-tpm-api` and `hoteru-bwalk-api` POST to the **private** `http://10.0.0.5:3140/api/service-events/events` (S002).

## Data
| Store | Detail |
|---|---|
| Postgres | `db` 16.9, DB `avilia`, owner role `avilia`. Prisma 6, 6 migrations (`20260909123011_init` … `20260910020147_add_p6_disputes_holds`), 23 tables (S001) |
| Redis | **none** (no code uses it) |
| Load-bearing secret | `SECRET_ENCRYPTION_KEY` AES-GCM-encrypts every hotel webhook secret (`ServiceSecret`). Lose it and every hotel must be re-provisioned. Only copy: `apps/backend/.env` on `app` (S001) |
| Prod rows (end S002) | 120 tenants (1 platform + 2 services + 117 affiliates), 118 users, 117 `__default__` rates, 0 transactions, 0 ledger entries |
| Backups | `/root/backups/pg/avilia/`, 8 dumps via Tier-2 auto-discovery (registry) |

`.env` names (8, registry): `NODE_ENV PORT HOST API_VERSION DATABASE_URL JWT_SECRET SECRET_ENCRYPTION_KEY ALLOWED_ORIGINS`.

## Deploy
- **Mode:** PM2 pull-on-host for the API + **static deploy app → proxy** for the portal (direct `devops@app` → `root@proxy` since 2026-10-20, skill `static-deploy-to-proxy`; Mac relay is the fallback).
- **Steps (S001/S002):** `git pull --ff-only` (pinned SHA), `pnpm install --frozen-lockfile`, **explicit `prisma generate`** (pnpm 10 skips dependency build scripts), `prisma migrate deploy`, `pnpm build:packages`, backend `tsc`, portal `vite build`, `pm2 restart avilia-api`.
- **Migrations:** `prisma migrate deploy` only. The repo's `db:migrate` script is `prisma migrate dev`: never on prod. Check `prisma migrate status` first (S002: up to date, none new).
- **Build-time vars:** none for the portal. It calls a relative `/api`, so an API host change needs no rebuild (S001).
- **Portal relay:** stage, verify `index.html` + the new hashed asset, then `rsync -a --delete` into `/var/www/avilia-app`; keep a timestamped copy. Never `rm` first (S002 incident).
- **Rollback:** API: previous SHA, rebuild, restart; pre-change `pg_dump` in `~/db-backups/*_pre_avilia_wiring_*.dump` (S002) is the precedent. Portal: the kept copy (`/var/www/avilia-app.bak-20260919-233217` exists, registry).

## Verify (after deploy)
| Check | Expected |
|---|---|
| `https://api.avilia.id/health` | 200 `{"status":"ok",…,"version":"v1"}`; `http://` → 301 |
| `https://api.avilia.id/nonsense-route-xyz` | 404 (proves nginx → Fastify) |
| Unsigned `POST /api/service-events/events` | 400; unauthenticated `/api/service-events/ledger` → 401 |
| `https://app.avilia.id/`, `/assets/index-*.js`, `/ops/ledger` | 200 / 200 / 200 (SPA fallback); `/api/auth/me` via portal → 401 |
| `https://avilia.id`, `www` | 200, title `Avilia — Segera Hadir` |
| Portal bundle | 0 `.dev.hoteru.uk` references; promo hosts `bwalk.hoteru.co.id`, `technoparkmalang.hoteru.co.id`, `demo.hoteru.uk` (S002) |
| Integration | signed re-sync of an existing affiliate from `app` → 201 per service (S002) |
| Logs | `~/.pm2/logs/avilia-api-out.log` / `-error.log` → OpenObserve stream `app` |
| GlitchTip / Kuma / OpenPanel | **none** (registry) |

## Known noise
- Request logs show `10.0.0.2` (proxy) as client IP: no Fastify `trustProxy` (S001).
- Unauthenticated `affiliate-sync` without a body → 400, not 401 (body validated before auth) (S001).
- `@fastify/rate-limit` registered with `global: false` and no route opts in: nothing is rate-limited (S001).
- `ServiceAgreement.pollingEndpoint` is NULL for both services: reconciliation polling is dormant (hoteru S019).

## Smoke test
- Safe: everything in Verify; a signed **idempotent re-sync of an existing affiliate** proves secret + signature + URL + network without new rows (S002).
- **Do not:** run `prisma/seed.ts` (creates a fake "Grand Bali Resort" hotel and 6 users sharing one known password) (S001); post fabricated booking events (the ledger must fill only from real bookings) (S002).

## Gotchas
1. Never delete the live static dir before the replacement is verified; never pipe a binary stream out of an SSH call that also prints text. Caused a 90 s `app.avilia.id` 403 (S002).
2. Repo deploy docs and `ecosystem.config.cjs` describe a single VPS; adapt, don't follow (S001).
3. `config.ts` silently falls back to the committed dev `JWT_SECRET` / `SECRET_ENCRYPTION_KEY` when unset; check at runtime that the real values loaded (S001).
4. pnpm 10 skips Prisma's build script: run `prisma generate` explicitly (S001).
5. HTTP-01 webroot, 4 names, no wildcard, no CF token: a new subdomain = re-issue with an extra `-d`; "Always Use HTTPS" breaks renewal; the proxy deploy hook reloads nginx after renewal (since 2026-10-19, proxy S008) (S001, registry §6).
6. Only affiliate **creation** syncs from Hoteru. Rate edits leave Avilia stale until the idempotent backfill is re-run (S002).
7. Hoteru callers must use the private URL; the Cloudflare hairpin can block server-to-server POSTs (S001/S002).
8. A rejected webhook is a non-2xx, not an exception: before hoteru PR #22 a bad secret looked like "no bookings" (S002). Check hoteru API logs for `logIfRejected` lines.
9. Promo links were hardcoded to staging hosts until PR #1; grep the bundle for `.dev.` after every portal build (S001/S002).
10. Central `~/hoteru` must stay unwired: 3 hotels in one process would share one `service_id` (S001/S002).

## Open items
- **All 117 synced affiliate logins share one default password.** Needs an invite/reset flow before affiliates are told the portal exists. Biggest risk (S002).
- Back up `SECRET_ENCRYPTION_KEY` + DB password to Vaultwarden (S001/S002).
- Uptime Kuma monitor for `https://api.avilia.id/health` (S001; registry: still none).
- Rotate the bootstrap `admin@avilia.id` password; human browser pass on the authenticated portal (S001).
- Watch for the first real attributed booking: 1 transaction + 2 ledger entries, `pending` → `payable` at check-out (S002).
- Upstream: fail-fast boot guard (Gotcha 3); `trustProxy` before any rate limit; rate-change sync hook in hoteru; fix or delete the single-VPS docs.
- 15% master rate is a standing pilot default (confirmed 2026-09-20), not a per-hotel agreement; revisit if Technopark's 14% implied margin is disputed (S002).
- `svc_radho` not provisioned; Radho tenant has no `AVILIA_*` (hoteru S019, registry `.env` names).
- **Registry vs reports:** README/S001/S002 say the `avilia` DB has no backup coverage; registry shows 8 dumps under Tier-2 auto-discovery, so that follow-up is done. Remove the stale `avilia-app.bak-20260919-233217` on proxy.

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep -w avilia-api; ss -tlnH | grep ":3140 "; git -C ~/avilia rev-parse --short HEAD; cut -d= -f1 ~/avilia/apps/backend/.env | tr "\n" " "; curl -s http://10.0.0.5:3140/health; echo'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'for d in hoteru hoteru-technopark hoteru-bwalk hoteru-radho; do printf "%s AVILIA_ENABLED=true lines: " $d; grep -c "^AVILIA_ENABLED=true" ~/$d/apps/backend/.env; done'
for u in https://api.avilia.id/health https://app.avilia.id/ https://avilia.id/; do curl -s -o /dev/null -w "%{http_code} $u\n" $u; done
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'certbot certificates --cert-name avilia.id 2>/dev/null | grep -E "Domains|Expiry"; ls -ld /var/www/avilia-app* /var/www/avilia.id'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d avilia -c 'select count(*) from _prisma_migrations where finished_at is not null'"
ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup 'ls -l /root/backups/pg/avilia/ | tail -3'
```
