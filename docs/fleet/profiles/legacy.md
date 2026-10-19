# legacy apps — compact profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** pasarbesar-app-reports up to session-002 (2026-05-21), asiaweek-app-reports up to session-003 (2026-06-03), app-sysadmin-reports sessions 001–005 (to 2026-07-22), projects-reports session-001 (2026-05-12), proxy-sysadmin session-007, registry + hosts 2026-10-19. Repo HEADs are local refs (not pulled); `wagrab-admin` origin checked with a dry-run fetch.
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

These apps run on `app` (`10.0.0.5`) under PM2 as `devops`, behind `proxy`, and most have no deploy history since spring 2025. Every cert below uses the nginx installer and renews and reloads itself. Before touching any of them, run release-preflight: there's no runbook and most checkouts carry prod-side edits.

## Footprint (one row per process)
| App | PM2 · port | cwd · runtime | Domain(s) | Repo · prod SHA (local HEAD) | Kuma |
|---|---|---|---|---|---|
| wagrab web | `wagrab-web` · 3002 | `~/wagrab-web/dist/ssr` · node 24 · **not git** (dist only) | wagrab.com, www | `biji-dev/wagrab-website` · unknown (`62c2908`) | #10 |
| wagrab team | `wagrab-team` · 3005 | `~/wagrab-team` · bash (Quasar SPA) | team.wagrab.com | `biji-dev/wagrab-team` · `2fb29dd` (same) | #27 |
| wagrab admin | `wagrab-admin` · 8001 | `~/wagrab-admin` · Directus 11.15 · **nvm node 22.22.0** | api. + admin.wagrab.com | `biji-dev/wagrab-admin` · `723d414` = origin/main (local stale `5e42516`) | #30, #31 |
| wagrab blog | `wagrab-blog` · 8003 | `~/wagrab-blog` · Ghost 5.109.0 (`current -> versions/5.109.0`) · **not git** | blog.wagrab.com | — | #28 |
| washop | `washop` · 3003 | `~/washop/dist/ssr` · node 24 | washop.me, www | `biji-dev/washop-app` · `1ed1bd2` (same) | #11 |
| teamy app | `teamy-app` · 7001 | `~/teamy` · **tsx in prod** | app.teamy.my | `biji-dev/teamy` · `de51785` (same), dirty `server/index.ts` | #22 |
| teamy web | `teamy-web` · 3001 | `~/teamy/landing` · bash | teamy.my, www | same repo | #21 |
| foucher voucher | `feyfa-voucher` · 3006 | `~/feyfa-voucher` · node 24 | foucher.co, www | local repo not found · `2add848` (2025-09-29) | #23 **DOWN 500 since 07-19** |
| foucher WA | `feyfa-wa` · 7004 | `~/feyfa-wa` · node 24, dirty `package.json` | wa.foucher.co | not found · `9c9e236` | #29 |
| foucher admin | `feyfa-admin` · 8002 | `~/feyfa-admin` · Directus 11.4 · **nvm node 22.22.0** | **none**: `foucher-admin.conf` disabled since 07-22 | not found · `6d2fc9c` | #35 **DOWN 526** |
| quranchat / qute web | `quranchat-app` · 3007 | `~/quranchat-app` · bash (Quasar) | quranchat.me, www **and** qute.my, www | `qute-dev/quranchat-app` · `972222a` (same) | #12, #24 |
| qute api | `qute-api` · 7005 | `~/qute-api` · node 24 (Koa) | api.quranchat.me **and** api.qute.my | `qute-dev/qute-api` · `028d1ce` (same) | #32, #33 |
| asiaweek | `asiaweek-web/-app/-api` · 7013/7014/7015 | `~/asiaweek/apps/{web,app,api}` · `/usr/bin/node` (api via `--import tsx`) | asiaweek.uk, www / app. / api. | `biji-dev/asiaweek` · `b43c83d`; **origin/main `81d1b4c` is 482 commits ahead** | none |
| pasarbesar | `pasarbesar` · 7002 | `~/pasarbesar` · node 24 via `dotenv -e .env -- node .next/standalone/server.js` | **beta.pasarbesar.id** (apex/www serve `/var/www/dummy`) | `biji-dev/pasarbesar` · `ee809d0`; main is 394 commits ahead (`9f48443`) | #25 |
| pasarbesar lpekinhub | `pasarbesar-lpekinhub` · 7003 | `~/pasarbesar-lpekinhub` · same launch form | lpekinhub.pasarbesar.id | same repo · `cbe42b4` (344 behind main) | none (#26 old domain, paused) |

## Data, certs and telemetry
| App | Data | Cert (expiry) | Telemetry |
|---|---|---|---|
| wagrab | PG `wagrab` (owner `wagrab`, **90 GB**, Directus); files on DO Spaces (`STORAGE_DIGITALOCEAN_*`); dump 39 GB × 5 = **191 GB of backup's 197 GB** | wagrab.com 12-31; admin.wagrab.com (admin, api) 01-01; team 01-01; blog 01-02 | Fluent Bit `app` stream only |
| wagrab blog | Ghost `config.production.json`; **storage engine not recorded** (if SQLite under `~/wagrab-blog`, it isn't in any backup) | blog.wagrab.com 01-02 | — |
| washop / teamy | none known (teamy `.env` holds AI provider keys only) | washop.me 01-01; teamy.my (apex, app, www) 01-13 | — |
| foucher | PG `feyfa` (24 MB); voucher reads Directus (`DIRECTUS_HOST`) | foucher.co (apex, samara-batu, www) 11-26; admin.foucher.co (admin/api/wa) 11-20 | — |
| quranchat/qute | **Mongo `quranchat` on db, no auth**, reachable from app + backup; nightly `quranchat-mongo.sh` dump (8 MB) | qute.my 01-01; quranchat.me 01-02 (both apex, api, www) | — |
| asiaweek | PG `asiaweek` (232 MB, 8 connections) | asiaweek.uk 12-07; app.asiaweek.uk (app, api) 12-24 | GlitchTip asiaweek 6/7/8; OpenObserve `asiaweek_api`; GA4 + OpenPanel (asiaweek s003) |
| pasarbesar | PG `pasarbesar` (dump 909 B, effectively empty), `pasarbesar-beta` (5 connections), `pasarbesar-lpekinhub` (0); Redis db0 `{pb-lpekinhub}:bull:*` (`REDIS_PREFIX`); DO Spaces; WhatsApp Cloud API via miaw-route (`PasarBesar - PROD` → `10.0.0.5:7002`) | pasarbesar.id (apex, beta, lpekinhub, www) 12-16 | GlitchTip pasarbesar 2 (lpekinhub only) |

## Deploy (per family)
- **General:** no CI, no runbook in most repos. projects-reports s001's rsync recipes are out of date: most prod dirs are git checkouts now, but several hold prod-side edits that a `git pull` would conflict with.
- **Directus (wagrab-admin, feyfa-admin):** any restart must keep the Node 22 interpreter: `pm2 restart <name> --interpreter ~/.nvm/versions/node/v22.22.0/bin/node`, then `pm2 save`, and check `ss` for the port (app-sysadmin s005).
- **Next.js standalone (pasarbesar ×2):** pasarbesar s002 owns the procedure: `HOSTNAME` in `.env`, detached `nohup` build, copy `.next/static` + `public` into the standalone tree, `dotenv` PM2 entry, verify an internal `/_next/static` asset. A move to `main` is a re-platform (monorepo `apps/web`), not a pull.
- **asiaweek:** repo `docs/operations/launch-runbook.md`, `rollback.md`, `provisioning.md`, `backups.md` own the procedure. Note from s002: build with `pnpm turbo run build`, migrate with `pnpm --filter @asiaweek/db migrate`, then **`pm2 delete` + `pm2 start ecosystem.config.cjs`** (a restart keeps the old env).

## Gotchas
1. `isolated-vm` can't build on Node 24. After the 07-22 Node 24 install, `wagrab-admin` stayed PM2-"online" with **no listening socket**, so check `ss`, not `pm2 ls` (app-sysadmin s005).
2. `wagrab-admin-out.log` reached 4.7 GB before pm2-logrotate was installed (app-sysadmin s001).
3. pasarbesar: `NEXT_PUBLIC_*` is baked at build time, and a foreground `next build` killed by an SSH drop left a half-built `.next` that PM2 crash-looped on (pasarbesar s001).
4. Standalone `server.js` reads `HOSTNAME`, not `HOST`; the repo `ecosystem.config.js` has wrong ports, so ignore it (pasarbesar s002).
5. "Failed to find Server Action" right after a pasarbesar restart is stale browser tabs, not a fault (pasarbesar s002).
6. Prod-side code edits: the DB pool `max: 5` in both pasarbesar apps (`src/lib/db/index.ts`) and `trust proxy` in `teamy/server/index.ts` were made on the server (app-sysadmin s001 #10). They show as dirty files today.
7. asiaweek validates `NODE_ENV` as `local|staging|production`; `development` crashes the api and app (asiaweek s002).
8. These legacy domains flapped together on 09-21/22 with nothing on the origin; edge-to-origin failures are only visible in Cloudflare analytics (proxy s007).
9. With `foucher-admin.conf` disabled, `admin.`/`api.foucher.co` land in the eventopia catch-all and get the `eventopia.my` cert (proxy survey 10-19).
10. `quranchat-app` serving both quranchat.me and qute.my (and `qute-api` both api hosts) is intended: one product, two brands (projects-reports s001). This answers the registry's "check if intended".

## Open items
- **foucher:** `foucher.co` has returned 500 since 07-19 (before the Node 24 change), cause unknown. `admin.foucher.co` returns 526 because the vhost is off, waiting on the domain renewal (memory: Node 24 follow-ups). dev runs a newer foucher stack (`foucher-api/-cms/-web`, `api.dev.foucher.co` on public `:8058`). Decide which is the future.
- **Fleet Node 24 native-module scan** is still pending (memory; app-sysadmin README).
- **pasarbesar:** apex/www serve a placeholder; prod is 394/344 commits behind a restructured `main`; `.env` has a malformed line (unquoted multi-line `FLOW_RSA_PRIVATE_KEY`) and a `.env.dev` sits in the prod checkout; which DB the main app uses isn't recorded (the busy one is `pasarbesar-beta`); no Kuma for lpekinhub; Kuma #40 `dev.pasarbesar.id` DOWN since 08-06.
- **Redis reattribution (registry 10-19):** `bull:commerce` (and probably `bull:scheduling`) in db0 belong to **seenow-workers**, not pasarbesar. pasarbesar main's own key prefix is unverified.
- **wagrab:** 90 GB DB drives 97% of backup storage; leftover `verify_wagrab_484379` (130 MB) on db; Ghost blog storage unknown; `wagrab-web` has no source on the server.
- **asiaweek:** `asiaweek-app-reports/README.md` lists only the dev footprint, but prod has run on app since s002. Dev seed accounts are still in prod (README). No Kuma monitor. CLAUDE.md doesn't list `asiaweek-app-reports/`. `/var/www/asiaweek.uk` is an unused static root. asiaweek s002 has a DB password in plain text (the redaction hook flagged it): rotate and redact.
- **Ecosystem files:** untracked for qute-api, feyfa-wa, feyfa-voucher, teamy, asiaweek; missing for wagrab-team, quranchat-app, washop, wagrab-admin, feyfa-admin (registry anomaly 9). Checkouts last committed Feb–Mar 2025: wagrab-team, feyfa-wa, feyfa-admin, quranchat-app, qute-api (anomaly 12).
- Long-DOWN dev monitors still alert: #37 `dev.wagrab.com`, #40, #42 `dev.teamy.my` (monitor survey). Pause them or bring the dev apps back.

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep -E "wagrab|washop|teamy|feyfa|quranchat|qute|asiaweek|pasarbesar"; ss -tlnH | grep -E ":(300[1-7]|700[1-5]|701[345]|800[123]) "'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'for d in wagrab-team wagrab-admin washop teamy feyfa-voucher feyfa-wa feyfa-admin quranchat-app qute-api asiaweek pasarbesar pasarbesar-lpekinhub; do printf "%s " $d; git -C ~/$d log -1 --format="%h %cs" 2>/dev/null || echo "not git"; git -C ~/$d status --porcelain 2>/dev/null | wc -l; done; echo "node22 pins in dump: $(grep -o "v22.22.0/bin/node" ~/.pm2/dump.pm2 | wc -l)"'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -c \"select datname, numbackends from pg_stat_database where datname in ('wagrab','feyfa','asiaweek','pasarbesar','pasarbesar-beta','pasarbesar-lpekinhub')\"; mongosh --quiet --eval 'db.adminCommand({listDatabases:1}).databases.map(d=>d.name)'"
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -l /etc/nginx/sites-enabled | grep -E "foucher|pasarbesar|wagrab|qute|quranchat|teamy|washop|asiaweek"'
for u in foucher.co wa.foucher.co beta.pasarbesar.id lpekinhub.pasarbesar.id asiaweek.uk; do printf "%s " $u; curl -s -o /dev/null -w '%{http_code}\n' https://$u/; done
```
