# hoteru — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** hoteru-app-reports up to session-019 (2026-10-09), registry 2026-10-19, repo docs at `fb56685` (= `origin/main` = deployed on all 4 prod checkouts)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| Doc (in `~/Projects/hoteru/`) | Use |
|---|---|
| `docs/deployment-prod.md` | central only, cluster-shaped; its `rsync devops@10.0.0.2` step doesn't work (Gotcha 6) |
| `docs/avilia-integration.md`, `docs/affiliate-commission.md` | Avilia contract, commission model |
| `docs/deployment-bwalk.md`, `docs/deployment-radho-syariah.md`, `docs/operations/dev-deployment.md` | **staging** records (`dev`); dev-deployment.md predates `*.dev.hoteru.uk` |
| `deploy.sh`, `runtime.sh`, `hoteru.nginx.conf`, `docs/deployment-technopark.md`, `docs/deployment-prod-avilia.md`, `docs/agents/deploying-to-prod.md`, `docs/agents/baseline-prod-tenant-dbs.md`, `docs/handoff-superadmin-purge.md` | **old single VPS `103.253.244.195`** (`/opt/hoteru`, `db push`, tar-pipe). Not ours; app facts only |
| Workspace | real runbook = [S019](../../../hoteru-app-reports/session-019-2026-10-09.md) (3-instance redeploy + tenant onboarding), [S008](../../../hoteru-app-reports/session-008-2026-08-12.md) (tenant onboarding), [S010](../../../hoteru-app-reports/session-010-2026-08-17.md) (migration baselining) |

## Instances
| | Central | Technopark | Bwalk | Radho | Dev staging |
|---|---|---|---|---|---|
| Host / checkout | app `~/hoteru` | app `~/hoteru-technopark` | app `~/hoteru-bwalk` | app `~/hoteru-radho` | dev `/home/deploy/hoteru` (shared, `.env.<tenant>`) + `/home/deploy/releases/…` |
| PM2 api / web | `hoteru-api` 3110, `hoteru-public` 3111, `hoteru-marketing` 3112 | `hoteru-tpm-api` 3120 / `-tpm-web` 3121 | `hoteru-bwalk-api` 3130 / `-bwalk-web` 3131 | `hoteru-radho-api` 3150 / `-radho-web` 3151 | api 4020/4021/4022/4026, sites 3020–3028 (`deploy`, loopback) |
| PM2 config | CLI start + `pm2 save` (S001); the tracked file is the dev layout | `hoteru-tpm.config.cjs` (untracked) | `hoteru-bwalk.config.cjs` (untracked) | `hoteru-radho.config.cjs` (untracked) | repo `ecosystem.config.cjs` |
| Web app dir | `apps/public`, `apps/marketing` | `apps/web/technopark` | `apps/web/bwalk` | `apps/web/radho-syariah` | all |
| Postgres (`db`) | `hoteru` (demo seed, S003) | `hoteru_tpm` | `hoteru_bwalk` | `hoteru_radho` | local PG 14 `hoteru_dev`, `hoteru_technopark`, `hoteru_bwalk`, `hoteru_radho_syariah`, `hoteru_admin`, `hoteru_campaign_staging` |
| Redis (`db` 10.0.0.1) | db 8 | db 9 | db 10 | db 11 | dev local Redis (Radho staging db 6) |
| Guest site | `demo.hoteru.uk`; marketing `hoteru.uk`/`www`, `hoteru.co.id`/`www` | `technoparkmalang.hoteru.co.id` | `bwalk.hoteru.co.id` | `radhohotelsyariahmalang.roomrate.co` | `*.dev.hoteru.uk` |
| API | `api.hoteru.uk` | `api.technoparkmalang.hoteru.co.id` | `api.bwalk.hoteru.co.id` | `api.radhohotelsyariahmalang.roomrate.co` | `api.<x>.dev.hoteru.uk` |
| Mgmt SPA (proxy static) | `app.hoteru.uk` → `/var/www/hoteru-app` | `/var/www/hoteru-tpm-app` | `/var/www/hoteru-bwalk-app` | `/var/www/hoteru-radho-app` | dev `/var/www/app.<x>.dev.hoteru.uk` |
| Proxy vhost | `hoteru.uk.conf`, `hoteru.co.id.conf` | `technoparkmalang.hoteru.co.id.conf` | `bwalk.hoteru.co.id.conf` | `radhohotelsyariahmalang.roomrate.co.conf` | dev nginx |
| Cert (DNS-01, `cloudflare/hoteru.ini`) | `hoteru.uk` + `hoteru.co.id` wildcards, 2027-01-13 | 3 SANs, 2027-01-15 | 3 SANs, 2027-01-08 | 3 SANs, 2027-01-06 | dev |
| Avilia | **unwired** (one process, 3 demo hotels) | `svc_technopark` live | `svc_bwalk` live | unwired | `*.dev.avilia.id` |

- All prod processes: fork, system Node v24.18.0, `HOSTNAME=10.0.0.5` for web; API `HOST`/`PORT` from `apps/backend/.env` (registry). Tenant processes have **no `max_memory_restart`**.
- `*.hoteru.co.id` (other names) → 200 holding page on proxy. Two-level `api.`/`app.<hotel>` records are **grey**; tenant apex orange; central names orange. CF Full (strict).
- Uploads: `/var/lib/hoteru/uploads/<hotelId>/` on app, shared by all 4, served by app nginx `10.0.0.5:8931` (the only vhost on app), proxied as `/uploads/` on every api host (S007).

## Data
- 18 Prisma migrations on all 4 prod DBs (latest `20260915000000_add_booking_campaign_label`) (S019). Additive so far.
- Redis dbs hold 0 keys (registry): nothing Redis-only to lose.
- Backups: `/root/backups/pg/{hoteru,hoteru_tpm,hoteru_bwalk,hoteru_radho}/`, 8 dumps each (registry). **Uploads dir has no backup.**
- Secrets files on app: `~/hoteru-technopark/.secrets`, `~/hoteru-bwalk/.secrets` (untracked, not ignored), `~/.hoteru-radho-credentials` (0600).
- `.env` names: backend `NODE_ENV PORT HOST DATABASE_URL REDIS_URL JWT_SECRET JWT_REFRESH_SECRET JWT_EXPIRES_IN JWT_REFRESH_EXPIRES_IN ALLOWED_ORIGINS API_VERSION UPLOAD_ROOT UPLOAD_BASE_URL` (+ `AVILIA_ENABLED AVILIA_EVENTS_URL AVILIA_SERVICE_ID AVILIA_SERVICE_SECRET` on tpm/bwalk). Sites: `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_<HOTEL>_HOTEL_ID`, `NEXT_PUBLIC_SITE_URL`. Mgmt: `VITE_API_BASE_URL VITE_PUBLIC_SITE_URLS VITE_ENABLE_MSW`.

## Deploy
- **Mode:** PM2 pull-on-host per checkout + **mgmt static deploy app → proxy** (direct since 2026-10-20, Mac relay fallback). One SHA for all instances; re-check `origin/main` == analysed SHA just before pulling (S019).
- **Pre-deploy:** `pg_dump -Fc` of each DB from `app` with that instance's `DATABASE_URL` → `~/db-backups/<db>_pre_sessionNNN_<ts>.dump`; save `pre-deploy-{pm2,head}-sessionNNN.txt` (S016–S019).
- **Per checkout:** `git pull --ff-only` → `pnpm install --frozen-lockfile` → `pnpm build:packages` → `prisma migrate deploy` + `migrate status` (only if migrations changed) → build only what the diff touches (backend `tsc`; guest site with `rm -rf .next` first; mgmt Vite; marketing central only).
- **Build-time:** every `NEXT_PUBLIC_*`/`VITE_*` (API base, hotel id, site URL). One build per tenant.
- **Restart:** `pm2 restart <name>` one name per call, only the changed processes, then `pm2 save` (S004).
- **Mgmt relay:** `scp` to proxy, stage `/var/www/.stage-<site>`, verify the asset exists and the bundle is bound to its **own** API, swap, keep `/var/www/.prev-<site>-<ts>`, `chown www-data`, drop `mockServiceWorker.js` (S004, S019).
- **Rollback:** previous SHA + rebuild + restart; DB from `~/db-backups/…` dumps; mgmt from `.prev-*`. Not rehearsed.
- **Node for builds:** not recorded in any report (runtime is system v24; nvm default is v22).

## Verify (after deploy)
| Check | Expected |
|---|---|
| `curl http://10.0.0.5:<api>/health` on app and `https://api.<host>/health` | 200 `{"status":"ok","version":"v1"}` for all 4 |
| Guest sites, tenant `/booking`, `app.<host>/` | 200; `/assets/*`, `/_next/static/*` 200 with fresh hashes |
| `GET /api/integrations/avilia/reconciliation` unsigned | central 503 (unwired), Technopark/Bwalk 401 (S019) |
| `/api/purge/bookings` unauthenticated | 401 (S011) |
| `pm2 logs <api>` | Prisma connected, Redis connected, listening, Scalar docs registered; empty error log (S017) |
| Mgmt bundle | contains its own `api.<host>` only (S019) |
| Logs | `~/.pm2/logs/hoteru-*-{out,error}.log` → OpenObserve stream `app` |
| GlitchTip / Kuma / OpenPanel | **none** (registry) |

## Known noise
- `000`/connection refused on `/health` within ~1 s of a restart; retry (S016).
- A deleted upload still 200 via Cloudflare cache (`cf-cache-status: HIT`, up to 4 h) on orange `api.hoteru.uk`; grey tenant api hosts drop at once (S007).
- `M apps/public/next-env.d.ts` in `~/hoteru` (generated) (S004, S019, registry).
- Radho `/r/[slug]` allow-list contains `radho-syariah.dev.hoteru.uk`; harmless (S019).
- `hoteru.co.id` marketing with no `Accept-Language` → `/en` (README).
- Browser-extension console warnings during browser passes are not app errors (S016).

## Smoke test
- Safe: Verify table; availability API (`availableCount`), server quote, gallery, CORS allow/deny, staff login + two refresh cycles, cross-tenant token rejection, upload → fetch via api host → exact-id delete → check disk (S008, S019 `smoke-radho.sh` 55/55).
- **Never POST a booking** to a prod tenant, even with 0 rooms: the backend returns 201 with `roomId` null. Assert the UI gate and before/after row counts instead (S019, memory).
- **Never run `db:seed`** (`seed.ts` deletes everything and creates demo hotels). Tenant seeds are per-clone untracked files (S002, S008, S011).
- Cleanup only by captured exact IDs, verify residue and total counts (S019, memory).

## Gotchas
1. Most repo deploy docs target the old single VPS; using them would mean `db push`/tar-pipe on prod (S004, S005, S010, S011, S019).
2. The tracked `ecosystem.config.cjs` is the dev layout (`/home/deploy/hoteru`, 40xx/30xx ports). Never `pm2 start` it on app (S004).
3. Next standalone needs `.next/static` + `public/` inside the standalone dir; `postbuild` does it now. Stale copies served old chunks (S004, S005).
4. `pnpm build:packages` before site/mgmt builds, always on a fresh clone (S002, S019).
5. `pm2 reload a b c` reloads only `a` (S004).
6. `devops@app` has no SSH to proxy; relay via the Mac as `root@proxy` (S004).
7. Tenant DBs were `db push`-managed until baselined with `migrate resolve --applied` (S010). Now `migrate deploy` only. Central's ledger has a resolved failure for `20260414_update_payments_table` (S004).
8. Role `hoteru` has no CREATEDB: dry-run scratch DBs are created as `postgres` on db (S004).
9. Two-level names can't be orange on the free plan (TLS handshake failure at the edge) (S002).
10. DNS-01 for new names: `--dns-cloudflare-propagation-seconds 45`; 10 s failed (S008). nginx reload after renewal: handled by the proxy deploy hook since 2026-10-19 (proxy S008).
11. A clone's `remote.origin.fetch` once pointed at a deleted branch; plain `git fetch` failed (S005, S006).
12. Referral cookie is host-only: tenant sites book through the same-origin `/api/bookings` proxy (S009).
13. Radho's site enables `robots: index` only on its exact production hostname (S019).
14. Untracked, non-ignored `.secrets` in two tenant trees: never `git add -A` there (registry).
15. Only affiliate creation syncs to Avilia; rate edits need the backfill re-run (S018).
16. Querying prod DBs from app: quote `DATABASE_URL`, redact output (memory "psql on app").

## Open items
- Radho: hotel must enter physical rooms; deliver staff credentials out-of-band, delete `~/.hoteru-radho-credentials`, rotate (shown once in the S019 transcript); `svc_radho` not provisioned (S019).
- Rotate the shared SUPERADMIN bootstrap password on central/Technopark/Bwalk (S011). Technopark's documented admin login no longer works (S008).
- Upstream: reject bookings with no AVAILABLE room (S019); rate-change sync hook (S018); commit per-tenant seed scripts (S019); delete or mark the single-VPS docs.
- Uploads dir: backup + orphan cleanup (S007).
- Delete `/var/www/.prev-hoteru-{app,tpm-app,bwalk-app}-20261009…` on proxy (S019, registry).
- First real attributed Avilia booking (S018). Bwalk real rates/photos; payment gateways unconfigured, pay-at-hotel (S008).
- Host→hotel tenancy on one build (milestone). Central `apps/public` attribution unverified (README).
- Ops gaps (registry): no Kuma/GlitchTip; no `max_memory_restart` on tenant processes; dev nginx still carries prod names `hoteru.uk`, `www`, `demo`, `public`, `manage`; dev `hoteru-api-bwalk` stopped while `hoteru-bwalk` is online (unexplained).
- **Registry vs reports:** (a) README says `hoteru_tpm`/`hoteru_bwalk`/`hoteru_radho` have no backup; registry shows 8 dumps each, so done. (b) `hosts/db-2026-10-19.md` labels Redis 9 = bwalk, 10 = technopark; S002/S008 and registry §4 say 9 = Technopark, 10 = Bwalk; this profile uses the registry. (c) README says there is no SSH path to `db` from the workstation; registry verifies `root@db` works. (d) S019 says `docs/deployment-prod*.md` describe the old VPS; `deployment-prod.md` actually describes the cluster (central only).

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep hoteru; ss -tlnH | grep -E ":(31[1-5][0-9]|8931) "; for d in hoteru hoteru-technopark hoteru-bwalk hoteru-radho; do echo "$d $(git -C ~/$d rev-parse --short HEAD) $(git -C ~/$d status --short | wc -l) dirty"; done'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'for p in 3110 3120 3130 3150; do printf "%s " $p; curl -s -o /dev/null -w "%{http_code}\n" http://10.0.0.5:$p/health; done; for d in hoteru hoteru-technopark hoteru-bwalk hoteru-radho; do printf "%s REDIS_URL db: " $d; grep "^REDIS_URL=" ~/$d/apps/backend/.env | grep -o "/[0-9]*$"; done'
for h in api.hoteru.uk api.technoparkmalang.hoteru.co.id api.bwalk.hoteru.co.id api.radhohotelsyariahmalang.roomrate.co; do curl -s -o /dev/null -w "%{http_code} $h\n" https://$h/health; done
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'certbot certificates 2>/dev/null | grep -A3 -E "Name: (hoteru|bwalk|technopark|radho)" | grep -E "Name|Expiry"; ls -d /var/www/hoteru-* /var/www/.prev-hoteru-* 2>/dev/null'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "for d in hoteru hoteru_tpm hoteru_bwalk hoteru_radho; do printf \"\$d \"; sudo -u postgres psql -XAt -d \$d -c 'select count(*) from _prisma_migrations where finished_at is not null'; done; redis-cli INFO keyspace; redis-cli CLIENT LIST | grep -o 'db=[0-9]*' | sort | uniq -c"
ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup 'for d in hoteru hoteru_tpm hoteru_bwalk hoteru_radho; do ls /root/backups/pg/$d/ | tail -1; done'
ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ~/.ssh/id_rsa deploy@dev 'pm2 ls | grep hoteru'
```
