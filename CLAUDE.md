# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository nature

This is **not a code repository**. It's a documentation workspace containing session-based reports written by Claude Code across recurring sysadmin and maintenance work. There is no build, no tests, no package manager. Work here is reading, writing, and updating markdown files.

Report series in this workspace:

- [disk-cleanup-reports/](disk-cleanup-reports/) — recurring macOS disk cleanup sessions for `/Users/dedi` on a 228GB disk. Each session documents what filled the disk, what was cleaned, and cumulative recovery across sessions. Sessions track *repeat offenders* (Claude.app vm_bundles, Chrome OptGuide model, Docker.raw) that regrow between sessions.
- [numa-sysadmin-reports/](numa-sysadmin-reports/) — sysadmin sessions for `root@numa` (Contabo VPS, `46.250.239.44`, Ubuntu 24.04.4). Topics so far: SSH hardening / security audit, OpenClaw daemon install.
- [app-sysadmin-reports/](app-sysadmin-reports/) — sysadmin sessions for `root@app` / `devops@app` (KVM VPS, `154.26.129.104`, Ubuntu 24.04.4). Production app server running 18 PM2 processes.
- [proxy-sysadmin-reports/](proxy-sysadmin-reports/) — sysadmin sessions for `root@proxy` (KVM VPS, `46.250.234.153`, Ubuntu 24.04.3). Public-facing nginx reverse proxy for the internal cluster.
- [db-sysadmin-reports/](db-sysadmin-reports/) — sysadmin sessions for `root@db` (`db.biji.uk`, `109.123.233.215`, Ubuntu 22.04.5). Database server: PostgreSQL 16, MariaDB, MongoDB, ClickHouse, Redis.
- [dev-sysadmin-reports/](dev-sysadmin-reports/) — sysadmin sessions for `root@dev` (`154.26.130.96`, Ubuntu 22.04.5). Multi-tenant dev host: 5 user workloads + Frappe/ERPNext docker stack.
- [erp-sysadmin-reports/](erp-sysadmin-reports/) — sysadmin sessions for `root@erp` (`217.15.166.117` / `10.0.0.6`, Ubuntu 24.04.4). ERPNext v16 for `gro.biz.id`, proxied via `proxy`.
- [backup-sysadmin-reports/](backup-sysadmin-reports/) — sysadmin sessions for `root@backup` (`194.233.81.93` / `10.0.0.4`, Ubuntu 22.04.5). Pull-based backup target for `db` + `erp`.
- [monitor-sysadmin-reports/](monitor-sysadmin-reports/) — sysadmin sessions for `root@monitor` (`217.15.162.56` / `10.0.0.3`, Ubuntu 24.04.2). Monitoring hub: GlitchTip / OpenPanel / Uptime-Kuma / Netdata / Vaultwarden.
- [projects-reports/](projects-reports/) — inventory of all local projects in `~/Projects/`. Documents tech stack, deploy targets, git remotes, running PM2 processes, and quick-fix deploy commands for `devops@app` and `deploy@dev`.
- [pasarbesar-app-reports/](pasarbesar-app-reports/) — **app-scoped** reports for the pasarbesar product family.
- [ytgrab-app-reports/](ytgrab-app-reports/) — **app-scoped** reports for the ytgrab product (`youtubegrab.com`). Docker compose stack on `app`; proxy nginx + SSL for `youtubegrab.com` / `api.youtubegrab.com`; error tracking on GlitchTip `biji/ytgrab`.
- [grobiz-app-reports/](grobiz-app-reports/) — **app-scoped** reports for the grobiz product (`gro.biz.id`), a multi-tenant UMKM SaaS. pnpm monorepo (Fastify API + Vite web/admin SPAs + static landing) under PM2 on `app`; per-tenant ERPNext sites auto-provisioned on `erp`; Postgres + Redis on `db`; proxy subdomains app/admin/api/apex.
- [wabacall-app-reports/](wabacall-app-reports/) — **app-scoped** reports for the wabacall product, a WhatsApp Business Calling API bridge (WebRTC, recording, AI voice agent). Runs on `dev` (`:19000`), public ingress `wabacall.dev.biji.uk`; Meta `calls` webhooks routed via the shared `miaw-route` router (`routes.biji.uk`) rather than a direct tunnel.
- [eventopia-app-reports/](eventopia-app-reports/) — **app-scoped** reports for the eventopia product (`*.dev.eventopia.my`), an organizer-first WhatsApp/QRIS event platform (repo `biji-dev/eventopia`; pnpm/turbo monorepo: api/workers/web-public/console/checkin). Deployed **bare-metal** on `dev` (system nginx + PM2 under `deploy` + local Postgres 14/Redis, **no Docker** — adapts the upstream Docker-Compose deploy). Subdomains: `www`/apex/`<org>` wildcard → web-public, `api` → Bun API, `app` → console, `checkin` → static PWA. Dev env with third-party doubles (fake payments/AI, WA Graph stub) + seeded org `kopikita-e2e`. Postgres role `eventopia` needs `BYPASSRLS`.
- [duitkas-app-reports/](duitkas-app-reports/) — **app-scoped** reports for the duitkas / baznas product, an AI WhatsApp expense bot (repo `biji-dev/miaw-flow`; Fastify API + WhatsApp/Socket.IO + Next.js dashboard). Runs under PM2 on `app` as `miaw-api-baznas`/`miaw-web-baznas` from `~/miaw-flow-baznas`, **private-bound** `10.0.0.5:7007/7008`; public ingress `baznas.duitkas.biji.uk` via `proxy` (grey-cloud DNS + LE cert, path-routed); Postgres `miawflow_baznas` + Redis on `db`.
- [seenow-app-reports/](seenow-app-reports/) — **app-scoped** reports for the seenow product (`*.dev.seenow.ac`), an AI-tutor LMS (repo `biji-dev/seenow`; Bun + Turbo monorepo: Hono API + BullMQ workers + Next.js public site + 4 Vite/React SPAs learner/teach/b2b/admin). Deployed **bare-metal** on `dev` (system nginx + PM2 under `deploy` + local Postgres 14/pgvector + Redis, **no Docker** — adapts the upstream Docker-Compose deploy). Subdomains: apex/`www` → web-public, `api` → Bun API (`:4900`), `learner`/`teacher`/`b2b`/`admin` → static SPAs (portals named on role-nouns; legacy `teach.` 301s to `teacher.`), `<tenant>.*` → learner with `X-Seenow-Tenant`. PG owner role `seenow` (`BYPASSRLS`, migrations/seed) + non-superuser `seenow_app` (RLS binds); Redis db3. AI via Anthropic Claude OAuth; object storage deferred. Wildcard TLS via DNS-01 (seenow.ac CF token). **Production** (`seenow.ac`) is deployed across the cluster (session-003), mirroring eventopia prod: CF orange/Full-strict → `proxy` nginx (LE `*.seenow.ac`, token `/etc/letsencrypt/cloudflare-seenow.ini`) → `app` `10.0.0.5:4900/4901` PM2 under `devops`; 4 Vite SPAs static on proxy `/var/www/seenow/*`; DB+Redis on `db` `10.0.0.1` (role `seenow` + `seenow_app`, Redis db7); no seed.
- [hoteru-app-reports/](hoteru-app-reports/) — **app-scoped** reports for the hoteru product, a hotel management platform for independent hotels (repo `biji-dev/hoteru`; pnpm/Turborepo monorepo: `backend` Fastify 5+Prisma 6 API, `public` Next 15 SSR guest site, `marketing` Next 15+next-intl EN/ID, `management` Vite/React-Router SPA). **Production** deployed across the cluster (session-001): CF orange/Full-strict on both `hoteru.uk` + `hoteru.co.id` → `proxy` nginx → `app` PM2 under `devops` (`hoteru-api` :3110, `hoteru-public` :3111, `hoteru-marketing` :3112, private-bound `10.0.0.5`); `management` SPA static on proxy `/var/www/hoteru-app`; Postgres `hoteru` + Redis db8 on `db`. **hoteru.uk** = product umbrella: apex/`www` marketing, `demo.` public site, `app.` management SPA, `api.` backend. **hoteru.co.id** = Indonesia: apex/`www` marketing landing; **`<hotel>.hoteru.co.id` is reserved one-subdomain-per-Indonesian-hotel** — wildcard cert + holding page issued, but app has **no host→hotel tenancy yet** (build-time API URLs); live per-hotel tenancy is the next milestone. Two LE wildcard certs via DNS-01 (`/etc/letsencrypt/cloudflare/hoteru.ini`).
- [meetgrab-app-reports/](meetgrab-app-reports/) — **app-scoped** reports for the meetgrab product (`meetgrab.us`), a Chrome extension that turns Google Meet captions into AI meeting summaries (repo `biji-dev/meetgrab`; pnpm/turbo monorepo: `api` **stateless Hono/Node LLM proxy**, `web` Astro static marketing site, `admin` Vite SPA *not deployed*, `extension` Chrome Web Store). **No database** (in-memory per-IP rate limiting). **Production** deployed across the cluster (session-001): CF orange/Full-strict → `proxy` nginx (LE cert via DNS-01 `/etc/letsencrypt/cloudflare-meetgrab.ini`, covers apex+`www`+`api`) → `meetgrab-api` under **PM2** on `app` (devops, **private-bound `10.0.0.5:8930`**, `node --env-file`, **no Docker** — repo ships a DO-droplet Dockerfile we don't use). `web` static on proxy `/var/www/meetgrab.us`; `api.meetgrab.us` is a **subdomain** (extension ships pointing at it; CORS whitelists `chrome-extension://…` + `https://meetgrab.us`). LLM: Anthropic **Haiku 4.5 via OAuth** (reused dogfood token, no refresh — soft-launch only) → **Gemini 2.5 Flash** fallback. Observability: GlitchTip API project 14, OpenPanel shared **MeetGrab Web** project, OpenObserve via `app` fluent-bit glob, web GA4 `G-KMVL074MH2`.

### Server-scoped vs app-scoped reports

There are two kinds of report directories:

- **`<server>-sysadmin-reports/`** — work that lives on one server: hardening, package upgrades, single-host nginx tweaks, backup configuration, kernel patches.
- **`<app>-app-reports/`** — work that revolves around one application but touches multiple servers (e.g. proxy + app + DB at once): domain rotations, env/secret changes, schema migrations, rebuilds, version bumps, deploys. The app's footprint and reasoning lives together rather than being scattered across server reports.

Pick by the *subject* of the change, not the surface area. A change that only edits nginx on proxy is server-scoped. A change that updates `.env` on `app`, rebuilds, adjusts proxy nginx + cert, and changes a DNS record — all because of one app — is app-scoped.

Each directory has a `README.md` index table that **must be updated** whenever a new session file is added.

## Session file conventions

Filename format: `session-NNN-YYYY-MM-DD.md` (zero-padded 3-digit number, ISO date). Number is monotonic per directory.

Standard frontmatter at the top of each session:
- Title `# Session N — <topic>`
- `**Date:**` (ISO)
- For numa: `**Server:**`, `**OS:**`
- For disk-cleanup: `**Disk before:**`, `**Disk after:**`, `**Recovered:**`

Body uses tables heavily (`Actions Taken`, `Findings`, `Cleanup Opportunities`, `Cumulative Summary`). Match the style of the most recent session in that directory rather than inventing a new layout — the cumulative-summary table in disk-cleanup is appended to each session and gains a new column per run.

When writing a new session, also update the `README.md` index table in the same directory with the new row.

## Screenshots

All screenshots taken during sessions (e.g. via Playwright MCP `browser_take_screenshot`) must be saved under `screenshots/` — never to the workspace root.

**Naming convention:** `screenshots/<server-or-app>-session-NNN-YYYY-MM-DD/<descriptive-name>.png`

Examples:
- `screenshots/monitor-session-004-2026-05-25/panel-1-result.png`
- `screenshots/ytgrab-session-002-2026-05-26/deploy-health-check.png`

The `<server-or-app>` prefix matches the report directory slug (e.g. `monitor`, `ytgrab`, `db`, `proxy`). Use the same date and session number as the session file being worked on.

## Cross-session context that matters

- Disk-cleanup sessions are cumulative: later sessions reference what earlier sessions did and call out *regressions* (things cleaned that came back). Read the most recent 1–2 sessions before writing a new one so you can name the regrowth correctly.
- Permanent fixes (e.g. "Claude.app uninstalled — VM regrowth cycle broken") are load-bearing — if a fix is listed as Done in a prior session, don't re-recommend it without checking current state.
- The `db`, `proxy`, `monitor`, `backup`, and `erp` servers form a private cluster on `10.0.0.0/24`: db `10.0.0.1`, proxy `10.0.0.2`, monitor `10.0.0.3`, backup `10.0.0.4`, erp `10.0.0.6`. Public traffic enters via `proxy`; stateful data lives on `db`; `backup` pulls dumps from db + erp. Sessions reference these by internal IP.
- Servers carry pending work forward: numa in its "Decisions Pending / Next Session Plan" section, and the cluster servers (backup, monitor, erp) in an "Open follow-ups" section in their `README.md`. Pick these up rather than re-deriving from scratch.

## Workflow rules

### Server action approval

- **Read-only SSH** (logs, `ps`, `systemctl status`, `df`, `cat`, `tail`, health checks) → proceed freely, no approval needed.
- **Write steps** (installs, deploys, restarts, file edits, nginx reload, PM2 restart, DB changes, migrations) → describe the step and the commands it will run, then **wait for explicit user approval** before executing anything.
- Approval is **per step** (a logical unit of work), not per individual shell command within a step.

### Session commit convention

At the end of a session, commit when the user signals (e.g. "commit this session"). Stage the new session file(s) + README update(s) together and use this format:

```
docs(<dir-slug>): session-NNN — <topic> (YYYY-MM-DD)
```

Examples:
- `docs(ytgrab): session-019 — LB plan for CPU saturation (2026-06-25)`
- `docs(disk-cleanup): session-015 — Tier 1-3 cleanup, 11GB freed (2026-06-24)`

If a session touches multiple directories, one commit covers all of them.
