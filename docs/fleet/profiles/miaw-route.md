# miaw-route — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** miaw-route-app-reports up to session-008 (2026-06-08), app-sysadmin session-004, wabacall session-001, eventopia sessions 007/008, grobiz session-003, registry + hosts 2026-10-19, repo docs at `42998c5` (local `main` = `origin/main`, v0.11.0; prod runs `e261061`, 46 commits behind)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
- `~/Projects/miaw/miaw-route/docs/`: `runbook.md` (webhooks not arriving or not forwarded, global routes, retry queue), `releases/0.10.0.md` and `releases/0.11.0.md` (per-release deploy runbooks with schema steps), `deployment-guide.md`, `custom-deployment.md`, `api-reference.md`, `high-availability.md`. **The release runbooks assume Docker Compose and `./scripts/deploy.sh`; production is bare Bun under systemd** (see Deploy).
- Workspace: [README](../../../miaw-route-app-reports/README.md), sessions [008](../../../miaw-route-app-reports/session-008-2026-06-08.md) (PM2 → systemd), [007](../../../miaw-route-app-reports/session-007-2026-06-08.md) (routes on `10.0.0.5`), [004](../../../miaw-route-app-reports/session-004-2026-06-06.md) (timestamptz migration), [002](../../../miaw-route-app-reports/session-002-2026-06-04.md) (observability, CSS build step).

## Footprint
WhatsApp Cloud API webhook router: Meta → `routes.biji.uk/webhook/<app-uuid>` → signature check → forwarded to a backend chosen by phone number / WABA id, plus a dashboard.

| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| router + dashboard | app | **systemd** `miaw-route.service`, User=devops, cwd `/home/devops/miaw-route`, `bun --env-file=.env.production src/index.ts`, `MemoryMax=600M`, active since 2026-10-15 05:56 CEST | **`0.0.0.0:9001`** (UFW is the only guard) | `routes.biji.uk` | cert `routes.biji.uk`, nginx installer, exp 2026-12-29, reloads itself |
| vhost | proxy | `routes.biji.uk.conf` → `10.0.0.5:9001`; port 80 → 404 | — | — | — |

- Bun 1.3.14 (s001). Checkout on branch `codex/calling-status-compatibility` at `e261061` (2026-10-15, a commit that is **already in `main`**), dirty: `.env.production`, a `.bak`, untracked `ecosystem.config.cjs` (registry anomaly 11).
- Logs: journald (`journalctl -u miaw-route`) → Fluent Bit systemd input → OpenObserve `syslog` stream. The app also ships logs and traces itself (`OPENOBSERVE_*`, `OTEL_*` env).
- dev has its own `miaw-route` PM2 entry, **stopped** (dev survey). Production Meta traffic goes to the app/systemd instance only (eventopia s008).

## Routes (known from reports; the `routes` table in `miaw_route` is authoritative)
| Route | Backend | Since |
|---|---|---|
| GroBiz - PROD | `http://10.0.0.5:4000/api/webhooks/whatsapp` (auth by `x-miaw-token` = grobiz `WHATSAPP_FORWARD_SECRET`) | s007, grobiz s003 |
| PasarBesar - PROD | `http://10.0.0.5:7002/api/webhooks/whatsapp` | s006 |
| Default Echo (`is_default`) | `http://10.0.0.5:9001/echo` (in-memory ring of 50, no DB) | s005/s007 |
| wabacall (phone `109689798856637`, `calls` + `messages`) | `https://wabacall.dev.biji.uk/call-events` | wabacall s001 |
| Eventopia - PROD (WABA `2271807923577496`) | `http://10.0.0.5:38001/webhooks/whatsapp` | eventopia s008 |

Meta app **BIJI Dev** points at `routes.biji.uk/webhook/d7745f14-…` and is shared by PasarBesar, wabacall and Eventopia. After a DB-side route change, call `POST /api/routes/reload` (admin key) (wabacall s001, eventopia s008).

## Data
- Postgres `miaw_route` on db, owner role **`miaw`** (the same role owns `miawflow_baznas` and `miawflow_lpekin`). 10 MB, 10 connections at survey. Tables: `apps`, `routes`, `webhook_logs`, `settings` (s004). Columns are `timestamptz` since s004. Nightly dump on backup.
- Redis **db1** on db: `dashboard_session` (6 keys). Only dashboard logins live there; losing it logs people out.
- In memory: the route cache, the retry queue worker, the echo ring buffer. Every inbound webhook is written to `webhook_logs` before it's forwarded (s005), so a restart loses no payloads, only queued retries in flight.
- Workers: retry (1 s), log-cleanup (3600 s), webhook-reconciler (300 s) (s004, s008).

## Deploy
- Mode: pull-on-host, **no build** (Bun runs `src/index.ts`). `dist/` is unused.
- Steps from the reports (s002–s005, s008): note the rollback SHA in `~/miaw-route-rollback-commit.txt` → `git pull` → `bun install --frozen-lockfile` (mandatory, top-level imports) → **`bun run css:build`** (the committed `public/css/styles.css` goes stale) → schema step if the release has one → `sudo systemctl restart miaw-route`. **Not `pm2`** (s008).
- Schema: `db:push` (drizzle-kit push) does **not** read `.env.production`. Pass `DATABASE_URL` explicitly, and never push a type change blind: s004 did the `timestamp → timestamptz` change by hand with `USING … AT TIME ZONE 'Asia/Singapore'` after a `pg_dump`. ops-guard blocks drizzle over SSH unless you add the override marker.
- Pending: 0.10.0 and 0.11.0 both have schema changes and run `db:push` from `deploy.sh`, which **ignores a failed push** (`docs/releases/0.11.0.md` "Deploy"). 0.11.0 needs `DEPLOY_ENV=production` (the key is already in `.env.production`). Translate the `docker compose exec` steps to the systemd host before running.
- Rollback: `git reset --hard <rollback SHA>` → `bun install --frozen-lockfile` → `css:build` → restart (s002). Back to PM2 if ever needed: `systemctl disable --now miaw-route` then `pm2 start ecosystem.config.cjs` (s008).

## Verify (after deploy)
- `https://routes.biji.uk/health` → healthy with db + redis ok and the version. `/login` → 200 `text/html` (if it renders as raw text, the OTel `onAfterHandle` content-type fix is missing, s002).
- `GET /echo` without a key → 401 (s005, s008). `systemctl is-active miaw-route` → active; `ss` shows `:9001`.
- `webhook_logs` shows new `status=success` rows for real traffic; the dashboard Logs page with "Show rejected" for signature or unknown-app failures (runbook).
- GlitchTip org biji, project 9 `miaw-route`. OpenObserve: `syslog` stream and the app's own stream.
- Kuma: **none** for `routes.biji.uk` (gap).

## Known noise
- Bun idles at a few % CPU; under PM2 it was 23% because of the fork wrapper (s008).
- 401/403 from backends on unsigned test posts. Those are the backends rejecting a missing signature or token (s006).
- 504s on `/login` when the host swaps hard: the cause was a ytgrab-api leak on app, not miaw-route (app-sysadmin s004).

## Smoke test
- Safe: `/health`, `/login` GET, `GET /echo` → 401, the webhook verify challenge (GET with `hub.challenge`) on the BIJI Dev app URL.
- Don't: post signed synthetic webhooks to the public URL in production unless you know which backend they'll reach; eventopia s008 did it on purpose, and it reaches real backends. Don't `db:reset`/`db:drop`/`db:seed` (repo scripts). Don't edit `routes` without the reload call.

## Gotchas
1. PM2's `env_file` didn't load; Bun's own `--env-file` does (s001). Same flag in the systemd unit (s008).
2. `HOST=127.0.0.1` gave a proxy 502; it must listen beyond loopback. It stays on `0.0.0.0` because its own health check uses loopback (s001, s007).
3. Committed CSS was stale twice; `css:build` is a standing deploy step (s002, s004).
4. The OTel plugin broke HTML content types until the `onAfterHandle` hook was added (s002).
5. Postgres session TZ is Asia/Singapore; naive timestamps were Singapore-local. Convert with an explicit `USING` (s004).
6. Bun under PM2 fork busy-polls (67% futex/sched_yield); run Bun under systemd (s008).
7. Backends on the same host should be reached on `10.0.0.5:PORT`, not via Cloudflare (s006, s007).
8. Webhooks for a number go nowhere until both the Meta subscription and a `routes` row exist; an empty `subscribed_apps` was eventopia's real fault (eventopia s008).

## Open items
- **Prod is 46 commits behind `main`** (0.10.0 and 0.11.0 unreleased, both with schema changes). `package.json` on prod still says 0.9.7.
- **No workspace report for the 2026-10-15 deploy** that put `e261061` (calling-status fixes) live from a feature branch. Last report is s008 (06-08). Memory rule: deploy from `main`, pin the SHA.
- **The wabacall route forwards to `wabacall.dev.biji.uk`, but wabacall is stopped on dev** (registry §3). Check the retry queue and the failed rows in `webhook_logs` for that phone.
- CLAUDE.md has no line for miaw-route or `miaw-route-app-reports/`. It also says the duitkas pattern uses miaw-route; duitkas actually uses the `miaw-core` QR provider (duitkas README).
- `0.0.0.0:9001` is protected only by UFW (registry anomaly 2). No Kuma monitor.
- Reports hold credentials in plain text: s001 (seed dashboard login, admin API key, global verify token) and s002 (OpenObserve ingest token). Rotate and redact.
- Untracked `ecosystem.config.cjs` and `.bak` in the prod checkout (anomaly 9). `devops` restarts the unit via passwordless sudo (app-sysadmin s001).

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 root@app 'systemctl is-active miaw-route; systemctl show miaw-route -p ActiveEnterTimestamp -p MemoryMax; ss -tlnH | grep ":9001"'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'git -C ~/miaw-route log -1 --format="%h %cs %s"; git -C ~/miaw-route branch --show-current; grep "\"version\"" ~/miaw-route/package.json'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d miaw_route -c 'select name, backend_url, is_default from routes order by name' -c \"select status, count(*) from webhook_logs where received_at > now() - interval '1 day' group by 1\"; redis-cli -n 1 DBSIZE"
curl -s https://routes.biji.uk/health; echo; curl -s -o /dev/null -w '%{http_code}\n' https://routes.biji.uk/echo
```
