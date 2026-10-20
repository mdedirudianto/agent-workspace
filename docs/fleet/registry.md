# Fleet registry

**Verified live:** 2026-10-19 06:26–06:40 WIB (§6 hook added 07:09) (2026-10-18T23:26Z onward), read-only surveys of app, db, proxy, dev, erp, monitor and backup. numa was not surveyed: SSH there needs per-session approval.
**Raw survey snapshots:** [`hosts/`](hosts/) (one file per host, same date).
**Rule:** this file goes stale. Before allocating anything or relying on a number, run that row's **verify-live** command and update the row and the stamp.

Used by the ops skills (`ops-session`, `release-preflight`, `pm2-app-deploy`, `static-deploy-to-proxy`, `new-app-to-cluster` and others) and by people. App-specific facts live in [`profiles/`](profiles/).

---

## 1. Hosts

| Host | Public | Private | OS | Clock | SSH as | Role |
|---|---|---|---|---|---|---|
| proxy | 46.250.234.153 | 10.0.0.2 | Ubuntu 24.04.3 | WIB | `root` only. A wrong user gets a **24 h fail2ban ban** | nginx 1.24 + certbot 2.9 for every domain, static roots `/var/www` |
| app | 154.26.129.104 | 10.0.0.5 | Ubuntu 24.04.4 | **Europe/Berlin (CEST)** | `devops` (`-i ~/.ssh/devops`), `root` for system reads | 47 PM2 apps + pm2-logrotate under `devops`, miaw-route on systemd. 6 vCPU / 11 GiB / 4 GiB swap (1.8 used) |
| db | 109.123.233.215 (`db.biji.uk`) | 10.0.0.1 | Ubuntu 22.04.5 | WIB (Postgres session TZ **Asia/Singapore**) | `root` | PG 16.9, Redis 8.6.1, MariaDB 10.6 (52 ERPNext site DBs), Mongo 8.0, ClickHouse 26.1. ytgrab-api + bgutil-pot on root PM2 |
| erp | 217.15.166.117 | 10.0.0.6 | Ubuntu 24.04.4 | **Europe/Berlin (CEST)** | `root` (bench user `frappe`) | Frappe 16.9 / ERPNext 16.6.1 / hrms 16.4.1 (detached HEAD); 52 sites; DBs on db's MariaDB |
| monitor | 217.15.162.56 | 10.0.0.3 | Ubuntu 24.04.4 | **Europe/Berlin (CEST)** | `root` | Docker: GlitchTip, OpenPanel, Uptime Kuma, Netdata parent, Vaultwarden, OpenObserve; `/opt/telegram-alerts` cron |
| backup | 194.233.81.93 | 10.0.0.4 | Ubuntu 22.04.5 | WIB | `root` | pull backups `/opt/backup` → `/root/backups` (db PG + Mongo, erp bench, grobiz sites/appconfig/wasessions). Local-only, unencrypted |
| dev | 154.26.130.96 | — | Ubuntu 22.04.5 | WIB | `deploy` with **`-i ~/.ssh/id_rsa`** (not `dev-deploy`, which is refused), `root` for system reads | shared, swap-bound dev box: 57 PM2 procs under `deploy` (22 online), local PG 14 + Redis 6, nginx (45 vhosts), OpenVPN, docker (grobiz ERPNext, miaw-sip-staging). **No UFW** |
| numa | 46.250.239.44 | 10.0.0.7 | Ubuntu 24.04.4 | — | `root`, **per-session approval** | personal box; ytgrab-api primary (`:7009`, weight 2) |

- **dev:** the only Mac key `deploy@dev` accepts is `~/.ssh/id_rsa` (`rsa-key-20160704`, 2016). Add a replacement key before anyone prunes it (dev session-001 H6).
- Always pass `-o BatchMode=yes -o ConnectTimeout=15`. `~/.ssh/config` is empty and `/etc/hosts` maps the short names, so a bare `ssh proxy` connects as the local user `dedi` and counts as a failed auth. The `ops-guard` hook blocks that for proxy.
- `app` cannot SSH to `proxy`. Static artifacts relay app → Mac → proxy.
- Normalise times in reports. PM2 log times on app and erp are CEST (WIB − 5 h); db and proxy are WIB; Playwright is UTC.
- Verify live: `ssh … 'timedatectl | grep "Time zone"; hostnamectl | grep Operating'`.

## 2. Ports on `app` (10.0.0.5)

Everything binds `10.0.0.5` unless marked. **Next free app port: 3180** (31x0 band, step 10). Verify with `ssh -o BatchMode=yes -i ~/.ssh/devops devops@app 'ss -tlnH | awk "{print \$4}" | sort -u'`.

| Port(s) | Process (PM2 unless noted) | Domain(s) on proxy |
|---|---|---|
| 3001 | teamy-web | teamy.my, www |
| 3002 | wagrab-web | wagrab.com, www |
| 3003 | washop | washop.me, www |
| 3005 | wagrab-team | team.wagrab.com |
| 3006 | feyfa-voucher | foucher.co, www |
| 3007 | quranchat-app | quranchat.me, www **and** qute.my, www (two vhosts point at one port; check if intended) |
| 3009 | ytgrab-web | youtubegrab.com (web part) |
| 3110 / 3111 / 3112 | hoteru-api / hoteru-public / hoteru-marketing (central `~/hoteru`) | api. / demo. / apex+www hoteru.uk; hoteru.co.id apex → 3112 |
| 3120 / 3121 | hoteru-tpm-api / hoteru-tpm-web | api. / apex technoparkmalang.hoteru.co.id |
| 3130 / 3131 | hoteru-bwalk-api / hoteru-bwalk-web | api. / apex bwalk.hoteru.co.id |
| 3140 | avilia-api | api.avilia.id, app.avilia.id (API paths) |
| 3150 / 3151 | hoteru-radho-api / hoteru-radho-web | api. / apex radhohotelsyariahmalang.roomrate.co |
| 3160 | rekrutme (fork ×1, nvm Node 22) | rkrt.me |
| 3170 | pahala (fork ×1, nvm Node 22) | pahala.co |
| **3180** | **next free** | |
| 4000 | grobiz-api (`~/grobiz-releases/current`) | app./api./admin. gro.biz.id |
| 4720 | grobiz-wa-gateway (**127.0.0.1**, intended) | — |
| 4900 / 4901 | seenow-api / seenow-web-public | api.seenow.ac / seenow.ac |
| 7001 | teamy-app | app.teamy.my |
| 7002 / 7003 | pasarbesar / pasarbesar-lpekinhub | beta. / lpekinhub. pasarbesar.id |
| 7004 | feyfa-wa | wa.foucher.co |
| 7005 | qute-api | api.qute.my **and** api.quranchat.me (shared upstream) |
| 7007 / 7008 | miaw-api-baznas / miaw-web-baznas | baznas.duitkas.biji.uk |
| 7013 / 7014 / 7015 | asiaweek-web / -app / -api | asiaweek.uk / app. / api. |
| 7016 | grobiz-admin (`pm2 serve`, **0.0.0.0**) | admin.gro.biz.id (static part) |
| 7017 | grobiz-landing (`pm2 serve`, **0.0.0.0**) | gro.biz.id, www |
| 7018 / 7019 | miaw-api-lpekin / miaw-web-lpekin | lpekin.duitkas.biji.uk |
| 8001 / 8002 / 8003 | wagrab-admin (Directus) / feyfa-admin (Directus) / wagrab-blog (Ghost) | api.+admin.wagrab.com / — / blog.wagrab.com |
| 8930 | meetgrab-api | api.meetgrab.us |
| 8931 | nginx (hoteru uploads, the only vhost on app) | `/uploads` on every hoteru api. host |
| 9001 | miaw-route (**systemd**, Bun, **0.0.0.0**) | routes.biji.uk |
| 9091 | eventopia-workers metrics (**all interfaces**) | — |
| 38001 | eventopia-api (**all interfaces**) | api.eventopia.my |
| 38100 / 38200 / 38400 | eventopia-web-public / -console / -operator | eventopia.my, `*.eventopia.my`, eventopia.co.id, custom domains / app.eventopia.my / admin.eventopia.co.id |

Not bound to 10.0.0.5 (only UFW keeps them off the internet): 7016, 7017, 9001, 9091, 38001. UFW on app also has stale `7007:7008` and `3000` rules open to Anywhere.

## 3. Ports on `dev`

Upstreams that dev nginx proxies to, with what the port means. Most bind loopback. **UFW is inactive** on dev, so the ones on all interfaces are public.

| Port | Process | Domain | State 10-19 |
|---|---|---|---|
| 3020–3028, 4020–4026 | hoteru instances + campaign sites (`releases/…`) | `*.dev.hoteru.uk` | online |
| 4030 | avilia-api staging | `*.dev.avilia.id` | online |
| 4900 / 4901 | seenow-api / web-public | `*.dev.seenow.ac` | **stopped** |
| 38001 / 38100 / 38200 / 38400 | eventopia api / web-public / console / operator | `*.dev.eventopia.my` | **stopped** |
| 6001–6003 | asiaweek | dev.asiaweek.uk | stopped |
| 7005 | pahala staging | dev.pahala.co | online |
| 7006 (all interfaces) | grobiz | dev.gro.biz.id, app./api./admin. | online |
| 7007 | rekrutme (staging, `6b28451`, Next 16, `next start` fork ×1, system Node 22, local PG `rekrutme` 13 tables) | dev.rkrt.me | online |
| 8058 (all interfaces) | foucher-api | api.dev.foucher.co | online |
| 18400 | docker (grobiz ERPNext nginx) | erp.dev.gro.biz.id | up |
| 19000 | wabacall | wabacall.dev.biji.uk | **stopped** |
| 5433, 5061, 9001, 9010 (all interfaces) | docker-proxy (PG container, SIP staging) | | up |
| UDP 1194 | OpenVPN (`openvpn@server`) | | active |

Stopped processes stay stopped unless the user asks. Full list in [hosts/dev](hosts/dev-2026-10-19.md). Verify with `ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ~/.ssh/id_rsa deploy@dev 'pm2 ls'` and `ssh -o BatchMode=yes root@dev 'ss -tlnH'`.

## 4. Redis on `db` (8.6.1, `10.0.0.1:6379`, 16 dbs)

**Next free: db 12** (12–15 have no keys and no clients). No password, `protected-mode no`, RDB only (AOF off), `maxmemory 0` / `noeviction`. UFW allows 6379 from monitor, app and numa only. **Never FLUSHDB.** Delete by `--scan --pattern` only.

| db | Keys (10-19) | Owner | Key prefixes |
|---|---|---|---|
| 0 | 49,220 | **shared**: **seenow-workers** (verified 10-19 by client address: all 11 of its connections are on db 0, although its `.env` says db 7), pasarbesar (+ lpekinhub queues), ytgrab rate limit (also numa), duitkas baznas (`baznas:` per docs) | `bull:commerce` = seenow (35,839 retained `commerce-reconcile` completed jobs, about +288/day, never pruned), `bull:scheduling` (likely seenow too, unverified), `{pb-lpekinhub}:bull:*`, `rl`, `video` |
| 1 | 6 | miaw-route | `dashboard_session` |
| 2 | 8 | GlitchTip (monitor) | `vt` |
| 3 | 4,452 | OpenPanel (monitor) | `groupmq`, `session`, `profile-cache`, `live` |
| 4 | 7 | grobiz prod | `geocode`, `tenant:*` |
| 5 | 2 | duitkas lpekin | `lpekin` |
| 6 | 6,508 | eventopia prod (**holds Redis-only state**: `org:*` identity, sessions) | `bull:wa-send`, `bull:payments`, `bull:ticket-delivery`, `org`, `membership`, `sess`, `wa` |
| 7 | 0 | seenow prod **on paper only**: `.env` `REDIS_URL` ends `/7`, but no client uses it (workers are on db 0, the api has no Redis connection). See profiles/seenow | — |
| 8 / 9 / 10 / 11 | 0 each, 1 client each | hoteru central / technopark / bwalk / radho (verified 10-19 by client address) | — |
| 12–15 | 0 | **free** | — |

The `app` Redis client is 7.0.15, so measure versions at the server. Runbooks that say "db 3" for grobiz quote the dev convention. Verify live: `ssh -o BatchMode=yes root@db 'redis-cli INFO keyspace; redis-cli CLIENT LIST | grep -o "db=[0-9]*" | sort | uniq -c'`.

## 5. Postgres on `db` (16.9)

`listen_addresses = localhost,10.0.0.1`. UFW allows 5432 from monitor, backup, app and numa. `pg_hba` allows `10.0.0.0/22` md5 (SCRAM is negotiated). Session TZ is **Asia/Singapore**, so be TZ-explicit in timestamp migrations. `backup_reader` (`pg_read_all_data` + BYPASSRLS) can read every DB, and backup's tier-2 auto-discovery picks up new DBs. Every DB grants CONNECT to PUBLIC.

| DB | Owner role | Size | App | Notes |
|---|---|---|---|---|
| wagrab | wagrab | 90 GB | wagrab (Directus) | biggest |
| glitchtip | glitchtip | 2.6 GB | GlitchTip | |
| ytgrab_prod | **postgres** | 669 MB | ytgrab | no app role; 0 connections at survey time |
| asiaweek | asiaweek | 232 MB | asiaweek | |
| eventopia | eventopia (BYPASSRLS, member of `app_tenant`) | 73 MB | eventopia | |
| feyfa | feyfa | 24 MB | feyfa | |
| grobiz | grobiz_user | 20 MB | grobiz | |
| openpanel | openpanel | 12 MB | OpenPanel | |
| seenow | seenow (CREATEDB/CREATEROLE/BYPASSRLS) + runtime `seenow_app` | 11 MB | seenow | |
| hoteru / hoteru_tpm / hoteru_bwalk / hoteru_radho | same-named roles | ~10 MB each | hoteru instances | |
| rekrutme | rekrutme (CREATE on DB for `drizzle`/`pgboss` schemas) | 10 MB | rekrutme | |
| pahala | pahala | 8 MB | pahala | |
| avilia | avilia | 10 MB | avilia | |
| miaw_route | miaw | 10 MB | miaw-route | |
| miawflow_baznas / miawflow_lpekin | miaw | 8 MB each | duitkas clients | |
| pasarbesar / pasarbesar-beta / pasarbesar-lpekinhub | pasarbesar | ~10 MB each | pasarbesar | |
| meetgrab | meetgrab | 9 MB | meetgrab | docs say meetgrab has no DB, so check whether it's used |
| verify_wagrab_484379 | postgres | 130 MB | — | leftover restore-verify DB |

Allocation for a new app: one role + one DB named after the app, the owner not a superuser, `CREATE` on its DB only if it creates schemas at runtime, untrusted extensions created as `postgres`. Verify live: `ssh -o BatchMode=yes root@db "sudo -u postgres psql -XAt -c 'select datname, pg_get_userbyid(datdba) from pg_database order by 1'"`.

**Other engines on db:**
- **MariaDB 10.6:** `10.0.0.1:3306`, UFW from erp only; 52 ERPNext site DBs `_<16hex>`.
- **Mongo 8.0:** `quranchat` only, **no auth**, from backup and app.
- **ClickHouse 26.1:** `openpanel` (243 MiB) with **`system` logs at 71.5 GiB** and no TTL; from monitor only.
- **Admin UIs on `db.biji.uk` through Cloudflare:** phpMyAdmin, pgAdmin4, mongo-express.

## 6. TLS on `proxy`

**35 certbot lineages. None under 30 days. Every served cert matches its file** (serials compared, 10-19).

**Deploy hook in place since 2026-10-19** ([proxy session-008](../../proxy-sysadmin-reports/session-008-2026-10-19.md)). `/etc/letsencrypt/renewal-hooks/deploy/10-reload-nginx.sh` runs `nginx -t -q && systemctl reload nginx` after every successful renewal. The 16 dns-cloudflare and webroot lineages (`installer = None`, "no" in the last column) depend on it. The 19 `nginx`-installer lineages also reload themselves. The hook's first real run is gro.biz.id around 10-22: check the served serial then. After that come meetgrab.us (~10-26) and erp.gro.biz.id (~10-27). The gro.biz.id DNS-01 dry-run passed on 10-19 with the default 10 s propagation.

| Cert | Domains | Expires | Method | Credentials | Reloads without the hook? |
|---|---|---|---|---|---|
| admin.foucher.co | admin/api/wa.foucher.co | 2026-11-20 | nginx | — | yes |
| gro.biz.id | `*.gro.biz.id`, apex | 2026-11-21 | dns-cloudflare | `cloudflare-gro.ini` (propagation **unset**) | **no** |
| youtubegrab.com | apex, api, www | 2026-11-22 | nginx | — | yes |
| meetgrab.us | apex, admin, api, www | 2026-11-25 | dns-cloudflare | `cloudflare-meetgrab.ini` | **no** |
| erp.gro.biz.id | `*.erp.gro.biz.id` | 2026-11-26 | dns-cloudflare | `cloudflare-gro.ini` | **no** |
| foucher.co | apex, samara-batu, www | 2026-11-26 | nginx | — | yes |
| v4.maxchat.id | v4.maxchat.id | 2026-12-01 | webroot | — | **no** |
| asiaweek.uk | apex, www | 2026-12-07 | nginx | — | yes |
| eventopia.co.id | apex, admin, www | 2026-12-07 | dns-cloudflare | `cloudflare-eventopia.ini` | **no** |
| biji.uk | apex, analytics, cockpit, errors, monitor, observe, status, vault, www | 2026-12-15 | nginx | — | yes |
| pasarbesar.id | apex, beta, lpekinhub, www | 2026-12-16 | nginx | — | yes |
| avilia.id | apex, api, app, www | 2026-12-18 | webroot | — | **no** |
| app.asiaweek.uk | app, api | 2026-12-24 | nginx | — | yes |
| sijari.uk | apex, www | 2026-12-25 | webroot | — | **no** |
| routes.biji.uk | routes.biji.uk | 2026-12-29 | nginx | — | yes |
| wagrab.com, admin.wagrab.com, team.wagrab.com, qute.my, washop.me, www.biji.uk | various | 2026-12-31 → 2027-01-01 | nginx | — | yes |
| blog.wagrab.com, quranchat.me | various | 2027-01-02 | nginx | — | yes |
| lpekin.duitkas.biji.uk / baznas.duitkas.biji.uk | single | 2027-01-06 / 01-07 | nginx | — | yes |
| radhohotelsyariahmalang.roomrate.co | apex, api, app | 2027-01-06 | dns-cloudflare | `cloudflare/hoteru.ini` | **no** |
| bwalk.hoteru.co.id | apex, api, app | 2027-01-08 | dns-cloudflare | `cloudflare/hoteru.ini` | **no** |
| eventopia.my | apex, `*.eventopia.my` | 2027-01-08 | dns-cloudflare | `cloudflare-eventopia.ini` | **no** |
| rkrt.me | apex, app, www | 2027-01-11 | webroot | — | **no** |
| hoteru.co.id / hoteru.uk | apex + wildcard | 2027-01-13 | dns-cloudflare | `cloudflare/hoteru.ini` | **no** |
| seenow.ac | apex, `*.seenow.ac` | 2027-01-13 | dns-cloudflare | `cloudflare-seenow.ini` | **no** |
| teamy.my | apex, app, www | 2027-01-13 | nginx | — | yes |
| technoparkmalang.hoteru.co.id | apex, api, app | 2027-01-15 | dns-cloudflare | `cloudflare/hoteru.ini` | **no** |
| pahala.co | apex, www | 2027-01-16 | webroot | — | **no** |

**Choosing a method for a new name:**
1. If the zone already has a Cloudflare token file on proxy, and the name is a wildcard or two-level, use **DNS-01** with `--dns-cloudflare-propagation-seconds 45`. Files are named per app, not per zone: `cloudflare/hoteru.ini` covers hoteru.uk, hoteru.co.id and roomrate.co. Check the token's zone scope, not the filename.
2. Otherwise use **HTTP-01 webroot** `/var/www/certbot`. Adding a subdomain means re-issuing, and Cloudflare "Always Use HTTPS" must stay **off** for that zone.
3. Two-level subdomains must be **grey-cloud** (Universal SSL covers one level only). Expect a 526 until the origin cert exists.

Verify live: `ssh -o BatchMode=yes root@proxy 'certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry"'`.

## 7. Proxy routing facts

- **No working catch-all on :443.** `eventopia-custom-domains.conf` has `server_name ~^.+$`. Regex names beat `default_server`, so **every unknown name** gets the eventopia.my cert and goes to eventopia web-public. That's a 403 unless the request comes through Cloudflare. **It also captures `<tenant>.seenow.ac`**, because the seenow tenant regex loads later. `00-default-catch-all` (444) only catches requests without SNI. Unknown names on :80 hit `default`, which returns 200 with the stock page.
- **Real files in `sites-enabled/`, not symlinks:** `eventopia.conf` (**drifted** from its sites-available copy, so the enabled file is authoritative), `eventopia-custom-domains.conf`, `partner.gro.biz.id.conf` (enabled only), `ytgrab-web.conf` (identical copy). Back up to `/root/nginx-backups/`, never into `sites-enabled/`.
- `.git/` is publicly served on biji.uk and biji.co.id. `/var/www/patriotjaya.id` has no vhost.
- The CF real-IP restore is **per vhost** (ytgrab, rekrutme, pahala), not global.
- fail2ban sshd: `maxretry 3`, `findtime 600`, `bantime 86400`, `ignoreip 127.0.0.0/8 10.0.0.0/24 103.119.54.100 157.85.208.16`.
- nginx `error.log` hasn't rotated since 2026-02 (`size 200M` overrides `daily`).

## 8. Static roots on `proxy` (`/var/www`)

| Dir | Served as | Deployed by |
|---|---|---|
| grobiz/order, grobiz/partner | order.gro.biz.id + `*.gro.biz.id`, partner.gro.biz.id | grobiz relay (`relay-static.sh`) |
| eventopia-checkin | checkin.eventopia.my | eventopia relay |
| hoteru-app, hoteru-tpm-app, hoteru-bwalk-app, hoteru-radho-app | app.<instance> | hoteru stage/`.prev` swap |
| seenow/web-{learner,teacher,b2b,admin} | learner./teacher./b2b./admin.seenow.ac (+ tenants, see §7) | seenow relay |
| meetgrab.us, meetgrab-admin | meetgrab.us, admin.meetgrab.us | meetgrab relay |
| avilia-app, avilia.id | app.avilia.id, apex | avilia relay |
| sijari.uk | sijari.uk | fresh clone of `biji-ext/sijari-web` (Mode B) |
| v4.maxchat.id, biji.uk, biji.co.id, dummy, html, certbot | various | manual |

There are 16 stale `.prev`/`.bak*` rollback dirs from 2026-07 → 10. Keep only the latest `.prev` per site.

## 9. Runtimes and versions (10-19)

| Item | Value |
|---|---|
| app Node | system `/usr/bin/node` v24.18.0 (what PM2's `node` interpreter means); nvm v22.22.0 (default) pinned for rekrutme, pahala, grobiz, wagrab-admin, feyfa-admin |
| app PM2 | 6.0.14 global; pm2-logrotate 50M / retain 7 / daily (compression not working: 0 of 534 rotated files gzipped) |
| app log shipping | Fluent Bit tails only `~/.pm2/logs/*-out.log` / `*-error.log` → OpenObserve `app` stream. **Not shipped:** grobiz (`~/grobiz/logs/`) and miaw-flow (`~/miaw-flow-*/logs/`). Vector separately ships ytgrab |
| app TZ in PM2 env | only rekrutme and pahala set `TZ=Asia/Jakarta` |
| proxy | nginx 1.24.0, certbot 2.9.0 (apt timer, twice daily) |
| db | PG 16.9, Redis 8.6.1, MariaDB 10.6.22, Mongo 8.0.10, ClickHouse 26.1.3 |

## 10. Expiry inventory

Nothing else tracks these. `fleet-health-check` reads this table.

| Item | Expires | Where | Note |
|---|---|---|---|
| admin.foucher.co cert | 2026-11-20 | proxy | nginx installer, auto |
| gro.biz.id cert | 2026-11-21 | proxy | renews ~10-22: first real run of the deploy hook, check the served serial |
| youtubegrab.com cert | 2026-11-22 | proxy | auto |
| meetgrab.us cert | 2026-11-25 | proxy | renews ~10-26 (deploy hook) |
| erp.gro.biz.id cert | 2026-11-26 | proxy | renews ~10-27 (deploy hook) |
| sijari.uk cert | 2026-12-25 | proxy | webroot (deploy hook) |
| rkrt.me domain | 2027-02-23 | registrar | auto-renew is an owner item |
| dev OpenVPN CA / server cert / CRL | 2034-06-21 / 2036-10-05 / 2036-10-05 | dev | daily check `/etc/cron.d/openvpn-cert-check` |
| erp DST shift | 2026-10-25 | erp, app, monitor | Europe/Berlin moves to CET: WIB offset becomes −6 h, server-local crons move 1 h against WIB |

## 11. Allocating for a new app

1. **Port:** next free in the app band (3180 now). Confirm with `ss -tlnH` on app. Bind `HOSTNAME`/`HOST` to `10.0.0.5`.
2. **Redis db:** next free (12 now), only if the app needs Redis. Confirm with `INFO keyspace` and `CLIENT LIST`. Prefix keys.
3. **Postgres:** role + DB named after the app (§5).
4. **Cert:** choose a method (§6) and add the row to §6 and §10.
5. **Static root:** `/var/www/<app>-<surface>`.
6. Update this file (row + stamp) in the same session, and add the app's `profiles/<app>.md`.
