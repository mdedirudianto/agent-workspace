# proxy — server profile

**Stamp:** profile v2 · 2026-10-19 (v2: certbot hook, S008) · sources: [registry.md](../../registry.md) (10-19), [hosts/proxy-2026-10-19.md](../../hosts/proxy-2026-10-19.md) (live, 06:26 WIB), [proxy-sysadmin-reports](../../../../proxy-sysadmin-reports/README.md) README + sessions 001–007 (004–007 read fully), app-scoped sessions that edited proxy (cited inline), CLAUDE.md, memory (`reference_ops_guard_hooks`, `feedback_never_delete_before_verifying_replacement`, `project_app_node24_followups`)

## Role
Public ingress for the whole cluster: nginx 1.24 + certbot 2.9 terminate TLS for every production domain (35 LE lineages, 52 enabled vhosts) and proxy to `app` 10.0.0.5, `monitor` 10.0.0.3, `erp` 10.0.0.6, `db` 10.0.0.1 and `numa` 10.0.0.7 (ytgrab API). Also serves the static SPAs under `/var/www`.
**Depends on it:** every public app — grobiz, eventopia, seenow, hoteru (4 instances), avilia, meetgrab, rekrutme, pahala, sijari, ytgrab, duitkas, pasarbesar, wagrab, teamy, qute/quranchat, foucher, asiaweek, miaw-route, maxchat v4, ERPNext tenants (`*.erp.gro.biz.id`), and the monitoring UIs (`errors/analytics/status/monitor/observe/vault.biji.uk`).

## Access
| User | How | Owns |
|---|---|---|
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy` (46.250.234.153) | everything: nginx, certbot, `/var/www`, fail2ban, netdata, fluent-bit |
| any other user | — | **none.** `dedi`, `devops`, `deploy` all count as failed auth |

- **fail2ban sshd:** `maxretry 3` / `findtime 600` / `bantime 86400` (24 h), counts failed *auth events*, so one wrong-user connection can ban instantly ([s004](../../../../proxy-sysadmin-reports/session-004-2026-07-14.md)). `ignoreip` 127.0.0.0/8, ::1, 10.0.0.0/24, 103.119.54.100, 157.85.208.16. 50 IPs banned at survey, 255 total.
- A bare `ssh proxy` connects as local `dedi` → ban. The `ops-guard` hook blocks wrong user / bare host for proxy. Stop after 2 failed attempts.
- Recovery route if the Mac is banned: `root@app` → `root@46.250.234.153` (public IP; the 10.0.0.2 path is now in ignoreip) ([s004](../../../../proxy-sysadmin-reports/session-004-2026-07-14.md)). `app` **cannot** SSH to proxy as devops; static artifacts relay app → Mac → proxy.
- UFW: default deny in; 22/80/443 from anywhere; all from `10.0.0.0/24` (eth1 is a /22). Netdata :19999 binds 0.0.0.0 but UFW has no public rule.

## Services
Server clock: **Asia/Jakarta (WIB)** — log times need no conversion. 4 vCPU / 5.8 GiB / 2 GiB swap (0 used) / disk 20 % of 96 G. Uptime 77 d, kernel 6.8.0-136.

| Kind | Unit | Schedule / detail (WIB) |
|---|---|---|
| systemd | `nginx` | master started 2026-10-16 06:22 WIB (restarted, not just reloaded); 4 workers |
| systemd timer | `certbot.timer` | twice daily, `certbot -q renew --no-random-sleep-on-renew`; last run 10-18 21:21. deploy hook `renewal-hooks/deploy/10-reload-nginx.sh` since 2026-10-19 (S008) |
| systemd | `fail2ban` | jails `sshd`, `nginx-http-auth` (30 in 60 s → 1 h; 0 bans ever) |
| systemd | `fluent-bit` | tails nginx access/error + journal → OpenObserve `10.0.0.3:5080` streams `nginx`, `syslog` ([s003](../../../../proxy-sysadmin-reports/session-003-2026-05-24.md)) |
| systemd | `netdata` | child, streams to monitor `10.0.0.3:19999`; local `health.d/web_log.conf` override ([s005](../../../../proxy-sysadmin-reports/session-005-2026-08-20.md), [s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md)) |
| systemd | `sshd` (socket-activated), `ufw`, `systemd-resolved` | — |
| logrotate | `/etc/logrotate.d/nginx` | daily run, but `size 200M` wins → rotates only past 200 MB |
| docker / PM2 | none | — |
| cron | not surveyed 10-19 | check `ls /etc/cron.d; crontab -l` |

## Change procedures
| Change | Sessions that did it | Safe pattern |
|---|---|---|
| nginx vhost edit + reload | proxy [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md); eventopia [s057](../../../../eventopia-app-reports/session-057-2026-08-17.md); ytgrab [s038](../../../../ytgrab-app-reports/session-038-2026-09-17.md); rekrutme [s003](../../../../rekrutme-app-reports/session-003-2026-10-14.md) | see bullets A |
| New vhost + cert, HTTP-01 webroot | sijari [s001](../../../../sijari-app-reports/session-001-2026-09-26.md); avilia [s001](../../../../avilia-app-reports/session-001-2026-09-19.md); rekrutme [s002](../../../../rekrutme-app-reports/session-002-2026-10-14.md); pahala [s001](../../../../pahala-app-reports/session-001-2026-10-18.md) | see bullets B |
| Cert via DNS-01 (Cloudflare) | hoteru [s001](../../../../hoteru-app-reports/session-001-2026-06-16.md); meetgrab [s001](../../../../meetgrab-app-reports/session-001-2026-06-22.md); grobiz partner vhost on the gro wildcard [s044](../../../../grobiz-app-reports/session-044-2026-09-24.md) | see bullets B |
| Disable a site | app [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) (foucher-admin); proxy [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) (cockpit, qute.dev) | remove the `sites-enabled` symlink only, keep `sites-available`; `certbot delete` only when the domain is gone |
| Static deploy to `/var/www` | sijari [s005](../../../../sijari-app-reports/session-005-2026-10-16.md); avilia s002 (90 s 403 incident) | see bullets C |
| fail2ban change | proxy [s004](../../../../proxy-sysadmin-reports/session-004-2026-07-14.md) | `cp jail.local jail.local.bak-<ts>`; edit; `fail2ban-client reload` (keeps bans, unlike restart) |
| Netdata alarm tuning | proxy [s005](../../../../proxy-sysadmin-reports/session-005-2026-08-20.md), [s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md) | override in `/etc/netdata/health.d/`, never edit `/usr/lib/netdata/conf.d`; back up first; `netdatacli reload-health`; confirm `source` via `/api/v1/alarms?all` |
| TLS protocol / global nginx | proxy [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) (TLSv1.2+ only, swap, 444 catch-all) | same as A |
| Package upgrade / reboot | none recorded in proxy reports | approval required; it is the single ingress, so schedule a window and verify every cert/vhost after |

**A. nginx edit**
- Back up to `/root/nginx-backups/<file>.<tag>-<ts>`, **never inside `sites-enabled/`** — the glob loads it as a duplicate vhost and `nginx -t` fails with `duplicate upstream` ([eventopia s057](../../../../eventopia-app-reports/session-057-2026-08-17.md)). ytgrab s038 used `/root/nginx-bak/`; prefer the one directory.
- Real files, not symlinks, in `sites-enabled/`: `eventopia.conf` (authoritative, drifted), `eventopia-custom-domains.conf`, `partner.gro.biz.id.conf`, `ytgrab-web.conf`. Edit the enabled file, then copy it back to `sites-available`.
- `nginx -t && systemctl reload nginx`. A failed `-t` leaves the old master serving (no outage) — but nothing applied.
- Guarded apply (pahala s001): stage the candidate in `/root/nginx-backups`, swap in, `nginx -t || restore`, then reload.
- nginx 1.24: no `http2 on;` directive; use `listen 443 ssl http2` (grobiz s044). Mixed http2 listens produce the known `protocol options redefined` warning.

**B. New name + cert**
- Zone has a CF token file on proxy and name is wildcard/two-level → DNS-01, `--dns-cloudflare-propagation-seconds 45` (gro.biz.id has none set). Check the token's zone scope, not the filename (`cloudflare/hoteru.ini` covers 3 zones).
- Else HTTP-01 webroot `/var/www/certbot`: stage a port-80-only vhost first, probe ACME through CF, issue, then full vhost (rekrutme s002, sijari s001). CF "Always Use HTTPS" must stay **off** for these zones; adding a SAN = re-issue.
- Two-level subdomains must be grey-cloud. Expect 526 until the origin cert exists (sijari s001).
- After issuing a dns-cloudflare/webroot cert, **reload nginx yourself** (no installer, no hook). Add the row to registry §6 and §10.
- Exact `server_name`s beat regexes; among regexes, file load order wins — `eventopia-custom-domains.conf` `~^.+$` currently swallows every later regex (seenow tenants).

**C. Static deploy**
- One SSH call per binary stream; validate the tarball locally; stage to `<dir>.new`; assert `index.html`; checksum; then swap `dir → dir.prev`, `dir.new → dir` (sijari s005). Never `rm -rf` the live dir first (avilia s002 → 90 s 403).
- Keep only the latest `.prev` per site; rsync from the Mac with `--exclude .remember`.

## Health checks (read-only)
```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy '
  nginx -t 2>&1 | tail -3; systemctl is-active nginx fail2ban fluent-bit netdata certbot.timer
  certbot certificates 2>/dev/null | grep -E "Certificate Name|Expiry"
  fail2ban-client status sshd | grep -E "Currently|Total"
  df -h / | tail -1; free -m | sed -n 2p; ls -la /etc/nginx/sites-enabled | grep -v -- "->"
  curl -s localhost:19999/api/v1/alarms?active | grep -c "\"status\": \"CRITICAL\""'
```
- Serial check for a cert (stale-cert detection, since master start time proves nothing): `echo | openssl s_client -connect 127.0.0.1:443 -servername <name> 2>/dev/null | openssl x509 -noout -serial` vs `openssl x509 -noout -serial -in /etc/letsencrypt/live/<cert>/fullchain.pem`.

## Known noise
- `error.log`: ~55 % `limiting connections, dry run` (ytgrab `limit_conn` dry-run zone), ~30 % `access forbidden by rule` (CF-only allow lists), `No route to host` to monitor :3333/:8000 (last 10-17), `Connection refused` to app :4000/:3009/:7017 during deploys.
- Netdata `web_log_1m_*`: scanner bursts on the catch-all; `unmatched`/`redirects`/`bad_requests` silenced, `successful` crit-only `<40 %` for 10 min, `internal_errors` kept ([s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md)).
- Multi-domain CF 522/525/526 flaps with zero nginx trace = Cloudflare↔origin path, self-recovers ([s007](../../../../proxy-sysadmin-reports/session-007-2026-09-22.md); 09-21 and 09-22).
- `[UFW BLOCK]` port-scan lines in the journal; `nginx -t` warning `protocol options redefined … vaultwarden.conf:15`.

## Open follow-ups
| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | Regex catch-all `eventopia-custom-domains.conf` (`~^.+$`) answers **every** unknown :443 name with the eventopia.my cert, incl. `<tenant>.seenow.ac` (tenant routing broken) and cert-only names (`admin/api/samara-batu.foucher.co`, `cockpit.biji.uk`). 444 catch-all only fires without SNI | new-on-10-19 | snapshot anomaly 1; supersedes [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) #2 | High |
| 2 | ~~No certbot deploy hook~~ **Done 2026-10-19 (S008):** `renewal-hooks/deploy/10-reload-nginx.sh`, gro.biz.id DNS-01 dry-run OK. Remaining: confirm the served serial after the first real renewals (gro.biz.id ~10-22, meetgrab.us ~10-26, erp.gro.biz.id ~10-27) | new-on-10-19 | snapshot anomaly 2 / S008 | Done, verify ~10-22 |
| 3 | `.git/` publicly served on biji.uk and biji.co.id (`/.git/config` 200); `/var/www/patriotjaya.id` orphan with `.git/` | new-on-10-19 | snapshot anomaly 4 | High |
| 4 | `foucher-admin.conf` re-enable once the owner renews foucher.co; meanwhile cert `admin.foucher.co` (also serves live `wa.foucher.co`) renews ~10-21 via nginx authenticator — watch it | carried | [app s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) | Med |
| 5 | `eventopia.conf` drifted again (enabled 08-21 vs available 08-17) after s057 reconciled it; `eventopia-custom-domains.conf`, `partner.gro.biz.id.conf` exist only in `sites-enabled` | new-on-10-19 (regression) | snapshot anomaly 5; [eventopia s057](../../../../eventopia-app-reports/session-057-2026-08-17.md) | Med |
| 6 | nginx `error.log` 110 MB, not rotated since 2026-02-24 (`size 200M` overrides `daily`); switch to `maxsize` | carried | [s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md) | Med |
| 7 | 407× HTTP 500 on `/`, vhost unknown — add `$host` to `log_format` | carried | [s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md) | Med |
| 8 | Origin-direct Kuma monitor (real `Host:` against 46.250.234.153) to tell CF-path flaps from real outages | carried | [s007](../../../../proxy-sysadmin-reports/session-007-2026-09-22.md) | Med |
| 9 | Prune 16 stale `.prev`/`.bak*` dirs in `/var/www` and 18 `*.bak*` files in `sites-available` (keep latest `.prev` per site; sijari `.prev` awaits owner OK) | new-on-10-19 | snapshot anomaly 6; [sijari s005](../../../../sijari-app-reports/session-005-2026-10-16.md) | Low |
| 10 | Unknown hosts on :80 get 200 stock page from `default` — make it 444 | new-on-10-19 | snapshot anomaly 8 | Low |
| 11 | Remove stale SANs/configs: `cockpit.biji.uk` SAN, `travelan-web.conf`, `api`, `no-ssl` in sites-available; decide `pasarbesar.id` apex (still `/var/www/dummy`) | carried | [s001](../../../../proxy-sysadmin-reports/session-001-2026-05-12.md) #3/#12, snapshot 7 | Low |
| 12 | Audit other hosts' fail2ban `ignoreip` for 10.0.0.0/24; decide on whitelisting the user's IP; nginx-http-auth jail has 0 bans ever — verify the filter works | carried | [s004](../../../../proxy-sysadmin-reports/session-004-2026-07-14.md), [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) | Low |
| 13 | quranchat.me and qute.my both → app :3007 (and api → :7005) — confirm intended | carried | registry §2 | Low |

## Drift: reports vs live 10-19
| Report said | Live 10-19 shows | Source |
|---|---|---|
| 443 `default_server` 444 stops unmatched hostnames | Only no-SNI clients hit it; regex `~^.+$` (eventopia, added ~07-14) takes all other unknown names | [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) #2 |
| eventopia.conf enabled/available reconciled | Differ again (enabled 08-21, available 08-17) | [eventopia s057](../../../../eventopia-app-reports/session-057-2026-08-17.md) |
| `ignoreip = 127.0.0.1/8 ::1 103.119.54.100 10.0.0.0/24` | also `157.85.208.16` — added without a report | [s004](../../../../proxy-sysadmin-reports/session-004-2026-07-14.md) |
| cockpit disabled | `biji.uk` cert still carries `cockpit.biji.uk` SAN, which now lands on eventopia | [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) #3 |
| 10.0.0.7 = unidentified Proxmox spare, no routes | numa; ytgrab_api upstream weight 2 at `10.0.0.7:7009` | [s002](../../../../proxy-sysadmin-reports/session-002-2026-05-12.md) #8 |
| 26 vhosts / 17 certs | 52 enabled entries (70 available) / 35 lineages | [s001](../../../../proxy-sysadmin-reports/session-001-2026-05-12.md) |
| nginx running continuously since 2026-09-21 | master restarted 2026-10-16 06:22 WIB (not in any proxy report) | [s007](../../../../proxy-sysadmin-reports/session-007-2026-09-22.md) |
| error.log 95 MB | 110 MB, still unrotated | [s006](../../../../proxy-sysadmin-reports/session-006-2026-09-20.md) |
| Backups go to `/root/nginx-backups/` | ytgrab s038 used `/root/nginx-bak/` — two backup dirs | [ytgrab s038](../../../../ytgrab-app-reports/session-038-2026-09-17.md) |
| Proxy README index ends at s007 (09-22) | Since then, proxy was changed only via app-scoped sessions (sijari, rekrutme, pahala, grobiz, hoteru) | README |

## Verify live
```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'timedatectl | grep "Time zone"; hostnamectl | grep Operating'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'nginx -T 2>/dev/null | grep -E "^\s*server_name" | sort | uniq -c | sort -rn | head'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls /etc/letsencrypt/renewal-hooks/*/; grep -l -E "(deploy|post|renew)_hook" /etc/letsencrypt/renewal/*.conf'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'echo | openssl s_client -connect 127.0.0.1:443 -servername foo.seenow.ac 2>/dev/null | openssl x509 -noout -subject'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'curl -s -o /dev/null -w "%{http_code}\n" -H "Host: biji.uk" https://127.0.0.1/.git/HEAD -k'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'grep -E "^ignoreip|^maxretry|^bantime" /etc/fail2ban/jail.local; ufw status numbered | head -20'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -ld /var/www/*.prev* /var/www/*.bak* /var/www/grobiz/*.bak* 2>/dev/null; ls -la /var/log/nginx/error.log*'
```
