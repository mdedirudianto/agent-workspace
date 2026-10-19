# grobiz — profile

**Profile version:** 3 · **Stamped:** 2026-10-19 13:25 WIB (deploy #7, session-064) · **Sources:** grobiz-app-reports up to session-063 (2026-10-19), registry 2026-10-19, repo docs at `24d55885b` (= `origin/main` = prod since deploy #6)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| What | Where (`~/Projects/grobiz/…`) |
|---|---|
| **Deploy, rollback, relay, restart cost** | `docs/guides/deployment-prod.md` §14 (14.1 release layout, 14.2 commands, 14.2.1 in-flight gate, 14.2.2 order/partner relay, 14.2.3 first deploy carrying the tool batch, 14.4 `.env` + gateway, 14.5 rollback, 14.6 restart cost, 14.7 money path); §15 backups; §16.4 logs |
| Deploy tool | `deployment/pm2/scripts/deploy.sh` (run the copy inside `~/grobiz-releases/current/`), `relay-static.sh` (Mac-side), `rollback.sh`; `deployment/pm2/ecosystem.config.cjs` |
| Per-release deploy notes + D-item ledger | `docs/ops/2026-10-10-consolidated-deploy-followups.md` ("Deploy note — …" sections); per-change runbooks in `docs/ops/` and `docs/runbooks/` |
| Gateways / channels | `docs/guides/deployment-xendit-gateway.md` (§0 boot guards), `deployment-whatsapp-channel.md`, `docs/runbooks/whatsapp-business-setup.md` |
| HRMS on tenant sites | `docs/runbooks/2026-09-25-cr-021-m2-hrms-platform.md` (`tenant:install-hrms`) |
| Scripts | `docs/guides/scripts.md` |
| Workspace reports | [session-064](../../../grobiz-app-reports/session-064-2026-10-19.md) (deploy #7, decimal sale qty; build OOM, D263), [session-063](../../../grobiz-app-reports/session-063-2026-10-19.md) (deploy #6, deploy-tool batch), [062](../../../grobiz-app-reports/session-062-2026-10-18.md) (read-only census), [061](../../../grobiz-app-reports/session-061-2026-10-18.md) (deploy #5), [060](../../../grobiz-app-reports/session-060-2026-10-18.md) (deploy #4), [058](../../../grobiz-app-reports/session-058-2026-10-15.md) (release-layout bootstrap) |
| Memory | `feedback_deploy_main_pin_sha`, `feedback_boot_gates_beyond_env_schema`, `feedback_dry_run_before_trusting_static_read`, `project_grobiz_hrms_rollout_pending`, `feedback_workspace_report_from_app_repo_sessions` |

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| API (Fastify) + seller `web` SPA | app | PM2 `grobiz-api`, cwd `~/grobiz-releases/current` | 10.0.0.5:4000 | app.gro.biz.id, api.gro.biz.id, `/api` of admin. | cert `gro.biz.id` |
| WhatsApp gateway | app | PM2 `grobiz-wa-gateway`, same cwd | **127.0.0.1:4720** (intended) | — | — |
| admin SPA | app | PM2 `grobiz-admin` = `pm2 serve current-static/apps/admin/dist --spa`, pm_cwd `~/grobiz` | **0.0.0.0:7016** | admin.gro.biz.id | `gro.biz.id` |
| landing | app | PM2 `grobiz-landing` = `pm2 serve current-static/apps/landing/dist` | **0.0.0.0:7017** | gro.biz.id, www | `gro.biz.id` |
| order PWA + online shop | proxy | `/var/www/grobiz/order` | — | order.gro.biz.id, `*.gro.biz.id` (shop) | `gro.biz.id` |
| partner portal | proxy | `/var/www/grobiz/partner` (`partner.gro.biz.id.conf`, real file in `sites-enabled/` only) | — | partner.gro.biz.id | `gro.biz.id` |
| ERPNext (Frappe 16.9 / ERPNext 16.6.1 / hrms 16.4.1) | erp | bench `frappe`, `/home/frappe/frappe-bench`; 52 sites = base + 48 tenants + 3 `pool-*` | 10.0.0.6 via proxy | erp.gro.biz.id, `<hash>.erp.gro.biz.id` (`erp-tenants.gro.biz.id.conf`) | cert `erp.gro.biz.id` (`*.erp`) |

- PM2 under `devops`, nvm **Node 22.22.0** for all four; fork ×1; `kill_timeout` 20000 on api/gateway; **no `max_memory_restart`**. Restart baseline after deploy #7: api ↺6, gateway ↺5, admin ↺5, landing ↺5.
- Releases: `~/grobiz-releases/<UTC>-<sha12>`, symlinks `current` + `current-static`, `KEEP_RELEASES=4`, `history.log`. `current/.env` → `~/grobiz/.env`. The `~/grobiz` checkout (`8e6739cb5`) is stale; the live code is the release dir.
- Certs `gro.biz.id` (apex + `*`, exp 2026-11-21, propagation **unset**) and `erp.gro.biz.id` (exp 2026-11-26), dns-cloudflare `cloudflare-gro.ini`, reloaded by the proxy deploy hook (since 2026-10-19, proxy S008).

## Data
| Store | Facts |
|---|---|
| Postgres `grobiz` on db | owner `grobiz_user`; 20 MB; migrations to **0086** applied by `db:apply-sql` (+ `db:check-drift`), 9 data migrations replayed each deploy |
| Redis db **4** on db | `REDIS_HOST`/`REDIS_PORT`/`REDIS_DB` (not a URL); keys `geocode`, `tenant:*`, `admin:session:*`, limiter keys. Losing it costs sessions and caches, not business data. Server is 8.6.1 (app's `redis-cli` 7.0.15 is only the client, S060) |
| MariaDB on db | one `_<16hex>` DB per ERPNext site (52); reachable only from erp |
| WhatsApp sessions | `WA_SESSION_PATH` on app (`creds.json` per paired instance; 1 paired on 10-18) |
| Backups | backup host every 6 h (00/06/12/18 WIB): `grobiz-pg`, `grobiz-sites` (per-site `bench backup --with-files`, `pool-*` excluded), `grobiz-appconfig` (`.env`), `grobiz-wasessions`. Pre-deploy `pg_dump -Fc` → `app:~/grobiz/backups/` |

## Deploy
- **Mode:** release dirs + `current` symlink, built on app from a pinned `origin/main` SHA. `~/grobiz-releases/current/deployment/pm2/scripts/deploy.sh --sha <full sha>` (`--plan` first; `--with-order` / `--with-partner` when those changed). The legacy `~/grobiz/deployment/pm2/scripts/deploy.sh` is a stub that exits 2 (S058). Run it in tmux with `| tee ~/grobiz/logs/<name>.log`.
- **Build heap (D263, from S064):** export `NODE_OPTIONS=--max-old-space-size=4096` in the tmux shell that runs `deploy.sh`. The `@grobiz/api` `tsc` build also compiles every test and needs ~2.5 GB against `app`'s 2 240 MB default; without the export the build dies with `JavaScript heap out of memory` → `EXIT=5`, nothing live changed (~9 min lost). The export reaches only install/build/migrate: `pm2_run` starts PM2 under `env -i` + `PM2_ENV_PASS`, so no grobiz process inherits it. Drop this line once D263's test-free build lands.
- **Before:** owner pushes the pin; confirm `origin/main` = analysed SHA (memory); read the deploy note in `docs/ops/…followups.md`; diff the boot path for new fail-closed guards (S027); dry-run every backfill (memory); `pg_dump` (W1); check the 09:00 WIB lifecycle run is not in flight.
- **Inside deploy.sh:** migrations applied before the flip (`[6/13] flip current`); gateway restarted only when the diff rule says so (any `packages/shared` change, S059); `health-check.sh`; tag `deploy-<UTC>`.
- **Static on proxy:** app cannot SSH to proxy as `devops` (S062 R1). order/partner go app → Mac → proxy via `relay-static.sh` (deployed with deploy #6 but **never yet run against proxy**: `--plan` first, from the Mac checkout at the release sha or later) or by hand: stage, md5 against the release, backup `…/order.bak-<ts>`, `rsync -rlt --delete`, then `chown -R www-data:www-data` with dirs 700 / files 600 (S058, S061).
- **Build-time vars:** `VITE_*` (web/admin/order/partner); the order app needs an explicit `VITE_API_URL` origin (guide §6.2).
- **`.env` changes:** validate a boot-guard change on a throwaway process on a spare port before restarting the live API (S039). Guide §14.4.
- **Rollback:** `~/grobiz-releases/current/deployment/pm2/scripts/deploy.sh --rollback [--to <id|sha12>]`: a flip to an already-built release, the schema stays (guide §14.5). After a rollback and a later re-deploy past 0086, bump `admin_users.token_version` once (S061). Don't roll the API back past deploy #4 except to stop an outage (S060).

## Verify (after deploy)
| Check | Expect |
|---|---|
| `curl http://10.0.0.5:4000/api/health` on app | `status ok`, postgres/redis/erpnext `ok` |
| `readlink ~/grobiz-releases/current{,-static}`; `tail history.log` | the new release; one `deploy` line |
| app./admin./partner.gro.biz.id `/` | each names the release's hashed `index-*.js` |
| Gateway `/instances` (token from `.env` via a 600 header file) | connected count = before |
| `~/grobiz/logs/api-out.log` at +0/+30/+60 min | level-50 = 0; `api-error.log` unchanged (0 bytes since 10-15) |
| PM2 | all four online, restart counts +1 only |
| Errors | GlitchTip org `grobiz`: 10 api, 11 web, 12 admin, 13 extension (none for `order`) |
| Logs / analytics | OpenObserve stream `grobiz_api` via the API's own `OPENOBSERVE_*` transport (Fluent Bit does not tail `~/grobiz/logs`); OpenPanel `grobiz`, `grobiz-admin`; GA4 `G-6C3YPF2YNR` (landing) |
| Kuma | no monitor for prod gro.biz.id (only `dev.gro.biz.id` and the ERPNext API/login monitors) |

## Known noise
- `402` on `/api/loyalty/program` for tenants on plans without loyalty (S059, S060).
- Two level-40 Gro OAuth boot notices per API start (S060, S061).
- Three `client error` lines from the health-check probes right after the flip (S060).
- `curl /pos` → 404 JSON without `Accept: text/html` (SPA fallback is HTML-only, S059). `GET /api/orders` without `?status=incoming` → 400 by design (S060).
- Retention prints `pid <n> ((sd-pam)): systemd's user-manager PAM helper, its cwd is unreadable by design: skipped`. That line is the D130 fix working, not a warning. A `retention skipped:` line now names a real blocker, so investigate it (S063).
- deploy.sh's own health poll logs ~8 `connect() failed (111)` on proxy for `/api/health?hc=N` in the ~20 s API restart gap (S063).
- GlitchTip grobiz-api: old `UnauthorizedError: Token tidak valid atau sudah kedaluwarsa` issues (#8, #9, #41, #59, #60, #128, #200) re-fire in bursts when one client calls with an expired JWT (S063).
- `PM2 reload grobiz-api` is not zero-downtime: ~30–60 s of 502 (S013).
- Expected after deploy #5: admins with old tokens get one 401 and must sign in again (S061).

## Smoke test
- **Default (S059–S061):** GET-only. Playwright with a throwaway profile and every non-GET `/api/` aborted; a short-lived owner access token signed on the host after a read-only owner-row read (no PIN change, no `/logout`); test tenants `2caaaf0a` (PPN on) and `59aba5d4`.
- **Throwaway accounts:** insert an admin/partner, drive the real sign-in, delete by exact id in one guarded transaction (S061).
- **Canaries:** `d6f28680` ZZ Smoke Test Retail, `f4c91773` ZZ Smoke Test FnB. Exclude them from revenue/loyalty figures; `d6f28680` holds a real paid invoice (S033, S039).
- **Never in prod:** `pnpm seed:admin` (weak accounts + committed TOTP secret, S003); a real sale/QRIS charge without approval; merchant PIN changes; Redis purges outside db 4.

## Gotchas
1. A boot guard outside the env schema refused `ADMIN_ENFORCE_2FA=false`: 7.5-min outage (S027).
2. Restarting the live API to test a boot-guard `.env` change (`PAYMENT_GATEWAY`) cost 92 s (S039).
3. `git pull origin main` in the old deploy shipped commits merged mid-analysis; pin the SHA (S041, S044).
4. `drizzle-kit push` hangs on `unique().nullsNotDistinct()`; prod uses `db:apply-sql` + drift gate (S004 → fixed S035).
5. Runbooks saying Redis "db 3" quote dev; prod is db 4 (S060).
6. `rsync -e 'ssh -n'` breaks rsync and left an empty copy that `--delete` pushed: order 403 for 10 s (S058). macOS openrsync has no `--chown` (S061).
7. `deploy.sh` restarts the gateway on any `packages/shared` change (D131, S059).
8. ~~(sd-pam) blocks retention~~ — fixed by D130, deployed S063: retention ran and pruned to 4 releases.
9. ~~Census STOPs on session keys~~ — fixed by D120, deployed S063.
10. The deploy-side in-flight gate (D94) runs after migrations and before the flip. It waits on processing **and due pending** provisioning/teardown rows, and its worst case is ≈62 min before a refusal. `--allow-inflight` (from S063 on) reads once and proceeds. Due teardown rows that no worker claims refuse every deploy (DEC-10). Pre-check the queue when in doubt (S063). The scheduler has a Monday 07:00 WIB weekly report/digest, 10:00 reminders and a 10:30 dine-in sweep: time deploys around them.
11. ERPNext Company key is `tenants.erpnext_company`; a `business_name` rename desynced it (S046; memory). Check whitespace first.
12. `tenant:install-hrms`: success = `reached` = site count, not `exit=0`; `--max-sites` defaults to 10 (S052; memory).
13. An aggregate runbook's "no backfill" was true for Postgres only; `backfill:shop-fields` was needed for ERPNext fields (S038).
14. A `pending_deletion` transition is required before purging an `active` tenant (S031).
15. Dev runs PostgreSQL 14 (prod 16), one shared ERPNext site; never run prod's `deploy.sh` there (S037, S042).
16. Tenant counts in the README go stale: re-query before scoping a backfill (S027, S041).
17. **The API build outgrew the default Node heap** (S064, D263): see Deploy › Build heap. `deploy.sh --plan` cannot show it; only the build does.
18. `deploy.sh` never decides `--with-order`/`--with-partner`: check which shared symbols `apps/order`/`apps/partner` import against the diff (S064 P7) before choosing a relay.

## Open items
- **Prod = `25eaaec8a`** (deploy #7, S064, flip 12:57:51 WIB 10-19): code = `c1801157b` (decimal sale qty) + 3 docs files; api 0.129.0, web 0.100.0, shared 0.149.0, admin 0.39.2 rebuilt; order 0.12.1 / partner 0.4.2 not relayed. No migration past 0086. Rollback `deploy.sh --rollback` → `20261018T233408Z-24d55885ba35`. Mobile 0.93.0 store release owed (R1 old-mobile residual live until then). Owed: D263 (test-free API build), D262 (LIVE BIRD zero-valuation sales refusal, tenant unidentified), the §3 1,25 Kg test sale, the first live `relay-static.sh` run (D100/D122), D233 (the D130 tests on Linux).
- **gro.biz.id cert renews ~10-22.** It's the first real run of the proxy deploy hook added 10-19 (proxy S008). The DNS-01 dry-run passed with the default 10 s propagation. Check the served serial afterwards (registry §6).
- `grobiz-wasessions` backup pull failed 3× in 5 days (10-14, 10-15, 10-18) (backup survey).
- grobiz logs (`~/grobiz/logs/`) are outside Fluent Bit and pm2-logrotate; a stale 25 MB `~/.pm2/logs/grobiz-api-out.log` is still tailed (app survey).
- admin/landing listen on 0.0.0.0 (pm2 serve can't bind); only UFW protects them.
- Lifecycle: 10-19 `298343aa` goes `past_due` against 250k (D121, owner-ruled); first M2 trial-end mint 2026-10-24 09:00 WIB (`687e7b0d`), then 10-25 (`2f5e4c58`): record `signing_kind` (S058).
- The other two active admins must sign in once (S061). Mobile 0.92.x store builds are separate sessions.
- Payments: `PAYOUT_GATEWAY` has no boot guard; set a minimum payout threshold (break-even ≈ Rp 383.800) before first payout; no real refund cycle proven (S039, S040).
- Gro runs on a static personal OAuth token, no renewal (S043).
- WABA id unresolvable with the prod token; 17/17 template sends failed (S048).
- **Registry vs README:** README's subdomain line says `erp.`/`*.` → ERPNext; since S036 tenants are `*.erp.gro.biz.id` and `*.gro.biz.id` serves the shop from `/var/www/grobiz/order`. Use the registry.
- **Registry vs memory:** memory counts 45 tenant sites (49 site DBs); erp on 10-19 has 48 tenant sites (52 total) and backup covers 48.
- Europe/Berlin moves to CET on 2026-10-25: app/erp log times become WIB − 6 h; erp's `30 2 * * *` base-site backup cron shifts 1 h against WIB.

## Verify live
```bash
APP='ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app'
$APP 'readlink ~/grobiz-releases/current ~/grobiz-releases/current-static; tail -3 ~/grobiz-releases/history.log; ls ~/grobiz-releases'
$APP 'pm2 ls | grep grobiz; pm2 describe grobiz-api | grep -E "exec cwd|interpreter"'
$APP 'ss -tlnH | grep -E ":(4000|4720|7016|7017) "; curl -s http://10.0.0.5:4000/api/health'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db 'redis-cli -n 4 DBSIZE'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'certbot certificates 2>/dev/null | grep -A3 "Name: gro.biz.id"; ls -ld /var/www/grobiz/*'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@erp 'ls /home/frappe/frappe-bench/sites | grep -c erp.gro.biz.id'
```
