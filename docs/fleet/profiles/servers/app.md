# app — server profile

**Stamp:** profile v2 · 2026-10-20 (failed-unit cleanup, backup S006) · sources: [registry.md](../../registry.md) (10-19), [hosts/app-2026-10-19.md](../../hosts/app-2026-10-19.md) (survey 2026-10-19 06:26 WIB), [app-sysadmin-reports](../../../../app-sysadmin-reports/README.md) README + sessions 001–005, CLAUDE.md, app-scoped reports (ytgrab 018/022, duitkas 001, grobiz 027, rekrutme 002, eventopia 069), memory (`project_app_node24_followups`, `feedback_psql_on_app_never_echo_db_url`, `reference_ops_guard_hooks`, `feedback_deploy_main_pin_sha`).
**Rule:** the live snapshot wins over older reports. Drift is in its own section below.

## Role
Production Node host for the cluster: 47 PM2 apps under `devops`, plus miaw-route on systemd. Public `154.26.129.104`, private `10.0.0.5`, Ubuntu 24.04.4, 6 vCPU / 11 GiB / 4 GiB swap, clock **Europe/Berlin**. Proxy terminates TLS and reaches it over `10.0.0.0/24`. State lives on `db`.
**Apps that depend on it:** teamy, wagrab (web/admin/blog/team), washop, feyfa/foucher, quranchat/qute, ytgrab-web (the API is on numa+db), hoteru ×4 tenants, avilia, rekrutme, pahala, grobiz (api/wa-gateway/admin/landing), seenow, eventopia, asiaweek, pasarbesar ×2, duitkas (baznas/lpekin), meetgrab-api, miaw-route (`routes.biji.uk`). Port map: [registry §2](../../registry.md).

## Access
| User | How | Owns / use for |
|---|---|---|
| `devops` | `ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app` | all PM2 apps, `~/.pm2`, every checkout in `/home/devops`, miaw-route (systemd `User=devops`), `NOPASSWD:ALL` sudo ([s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md)) |
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@app` (key only, `PermitRootLogin prohibit-password`, s001) | system reads, UFW, fail2ban, fluent-bit/vector/netdata config. root PM2 exists but is **empty** |
| `miaw` | no login use | the failed GitHub Actions runner `/home/miaw/actions-runner-flow` |
| ~~`deploy`~~ | **does not exist on app.** `deploy@app` fails as "Permission denied", which looks like a ban but isn't one ([s003](../../../../app-sysadmin-reports/session-003-2026-06-08.md)) | — |

- **fail2ban** sshd is active. It was configured as 5 tries / 10 min → 1 h ban ([s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md)); not re-surveyed on 10-19. `ignoreip` has the office IP `103.119.54.100`, the old `125.166.13.120` ([s003](../../../../app-sysadmin-reports/session-003-2026-06-08.md)) and the cluster range. The Mac's home IP is **dynamic** (eventopia s069 saw `125.166.13.146`), so wrong-user retries from home can ban you. The ban on app is milder than proxy's 24 h ban.
- `app → proxy` SSH: the registry says app can't reach proxy, so static files relay app → Mac → proxy. But eventopia [s069](../../../../eventopia-app-reports/session-069-2026-10-13.md) unbanned an IP on proxy *from* `root@app` over `10.0.0.2`. See Drift.

## Services
| Kind | Unit / process | State 10-19 | Notes |
|---|---|---|---|
| PM2 (devops) | `pm2-devops.service` → `pm2 resurrect` | active since 09-30 | PM2 6.0.14 global; dump saved 10-18 12:38 CEST = 47 apps (matches the live list) |
| PM2 (root) | `pm2-root.service` | active, **0 procs** | leftover from ytgrab-api/bgutil, which moved off (ytgrab s018/020) |
| systemd | `miaw-route.service` | active since 10-15 | bun, `0.0.0.0:9001`; restart it with `sudo systemctl restart miaw-route`, **not PM2** ([s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md)) |
| systemd | `nginx` | active | one vhost only: `hoteru-uploads.conf` on `10.0.0.5:8931` |
| systemd | `fluent-bit` | active | tails `~/.pm2/logs/*-out.log,*-error.log` → OpenObserve `10.0.0.3:5080` stream `app`; journal → `syslog` ([s002](../../../../app-sysadmin-reports/session-002-2026-05-24.md)) |
| systemd | `vector` | active | ytgrab logs → stream `ytgrab` (also tails the gone `ytgrab-api-*`) |
| systemd | `netdata` | active | `127.0.0.1:19999`, Telegram alarms ([s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md)) |
| systemd | `fail2ban`, `unattended-upgrades` | active | |
| failed | `actions.runner.biji-dev-miaw-flow.app`, `snap.certbot.renew` | cleared 2026-10-20 | runner unit disabled (its user `miaw` doesn't exist) and the expired `api.wagrab.com` renewal conf moved to `/root/disabled-20261020/` ([backup S006](../../../backup-sysadmin-reports/session-006-2026-10-20.md)); `systemctl --failed` is empty |
| Docker | — | **absent** (no `docker.sock`) | disabled in s004; the 10-19 survey reports it as not installed |

| Schedule | Server time (CEST) | WIB now | WIB from 10-25 (CET) |
|---|---|---|---|
| pm2-logrotate `rotateInterval 0 0 * * *` (50M / retain 7) | 00:00 | 05:00 | **06:00** |
| unattended-upgrades / apt-daily timers | not surveyed 10-19 | — | +1 h vs WIB |
| user crontabs | not surveyed 10-19 | — | — |

- **DST 2026-10-25:** Europe/Berlin moves to CET, so the WIB offset goes from −5 h to −6 h. PM2 log timestamps are server-local. Only `rekrutme` and `pahala` set `TZ=Asia/Jakarta`; the other 46 apps log and schedule in Berlin time.
- **Node:** PM2's `node` interpreter is system **v24.18.0** (NodeSource). nvm v22.22.0 is the **nvm default** and is pinned via `--interpreter` for wagrab-admin, feyfa-admin, rekrutme and pahala. grobiz also runs on 22.22.0.

## Change procedures
| Change | Done in | Safe pattern |
|---|---|---|
| PM2 restart / interpreter pin | [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) | `pm2 describe <app>` first and note `exec_interpreter`. **Never** plain-restart wagrab-admin/feyfa-admin, because that falls back to Node 24 and `isolated-vm` dies, leaving a "online, 0 restarts" zombie with no socket. Confirm the port with `ss -tlnp`, not PM2 status. `pm2 save`, then check `dump.pm2` |
| Memory caps | [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md) | Launch the real process (direct `node <entry>`), not a `pnpm`/`sh` wrapper, or the cap watches the wrapper. `--update-env` is flagged by ops-guard: use it only when the env change is intended. `pm2 save` |
| apt / Node upgrade | ytgrab [s022](../../../../ytgrab-app-reports/session-022-2026-07-22.md), [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) | `apt install nodejs` makes **needrestart bounce `pm2-devops`, so all 47 apps restart at once**. Plan a window. Scan for native addons (`find ~/*/node_modules -name '*.node'`) before the upgrade. Pinned apps keep their nvm path. Check every port afterwards |
| Log shipping | [s002](../../../../app-sysadmin-reports/session-002-2026-05-24.md), rekrutme [s002](../../../../rekrutme-app-reports/session-002-2026-10-14.md) | A log ships only if it is `~/.pm2/logs/<name>-out.log` / `-error.log`. Set `merge_logs: true`, or PM2 appends the id (`-46.log`) and nothing ships. Back up `fluent-bit.conf` before editing. Check the journal for `inotify_fs_add … <name>-out.log` |
| fail2ban / SSH | [s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md), [s003](../../../../app-sysadmin-reports/session-003-2026-06-08.md) | `cp jail.local jail.local.bak.YYYYMMDD`, edit, `fail2ban-client reload`, then verify with `fail2ban-client get sshd ignoreip`. Keep `10.0.0.0/24` |
| UFW | none since s001 | `ufw status numbered` first. Never touch `22` or `10.0.0.0/24 ALLOW`. Delete by number, one rule at a time. Close a public port by rebinding the app to `10.0.0.5` (duitkas [s001](../../../../duitkas-app-reports/session-001-2026-06-11.md)), not with UFW alone |
| Swap / memory incident | [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md) | Find the leaker (`ps -eo rss,cmd --sort=-rss`) and check PSI `/proc/pressure/io`. Run `swapoff -a && swapon -a` only when free RAM is well above swap used. `swappiness=10`; don't grow swap past 4 GB |
| Prod DB reads from app | memory `psql_on_app` | Use the quoted-var `p()` function plus a redaction `sed`. Never build psql inside a string var. Print `.env` **names only** |
| App deploys | app-scoped reports | Deploy from `main` and re-check `origin/main` == the analysed SHA (memory). grobiz deploys to `~/grobiz-releases/current`, not `~/grobiz` |

## Health checks (read-only)
```bash
D='ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app'
$D 'pm2 ls; pm2 jlist | python3 -c "import json,sys;[print(p[\"name\"],p[\"pm2_env\"][\"status\"],p[\"pm2_env\"][\"restart_time\"]) for p in json.load(sys.stdin) if p[\"pm2_env\"][\"status\"]!=\"online\" or p[\"pm2_env\"][\"restart_time\"]>10]"'
$D 'free -h; swapon --show; cat /proc/pressure/io /proc/pressure/memory; df -h /; uptime'
$D 'systemctl --failed --no-legend; systemctl is-active miaw-route fluent-bit vector netdata nginx pm2-devops'
$D 'ss -tlnH | awk "{print \$4}" | grep -vE "^(10\.0\.0\.5|127\.)" | sort -u'   # anything not private/loopback
$D 'sudo journalctl -u fluent-bit --since -1h --no-pager | grep -iE "error|retry" | tail -5'
$D 'sudo ufw status numbered; sudo fail2ban-client status sshd | tail -3'
```

## Known noise
- `ytgrab-web` restart count climbs about daily (500M cap). That's a known item, not a new incident.
- `systemctl --failed` should now be empty (the miaw-flow Actions runner and `snap.certbot.renew` were cleared 2026-10-20). Anything listed is new. After a host restart, `pm2-devops` brings all 48 PM2 entries back by itself (proven 2026-10-19).
- eventopia (3–4) and grobiz (3–4) restarts on 10-18 were deploys, not a crash loop.
- Stale `~/.pm2/logs` files: bgutil-pot, ecosystem.tpm, idle-test, miaw-route, ytgrab-api/be/fe, and the old 25 MB `grobiz-api-out.log`. Fluent Bit still tails that last one.
- Swap sits around 1.8 / 4 GiB. That is stale pages, below Netdata's `used_swap` warn level of 80 %.
- PM2 log times are CEST (WIB −5 h; −6 h from 10-25).

## Open follow-ups
| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | **Node 24 native-addon scan + one-by-one restart** of the other ~40 apps. Only the Directus pair was fixed | carried | [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md), memory | High |
| 2 | **ytgrab-web memory loop:** 57 restarts, at least 5 over the 500M cap on 10-17/18, no NODE_ENV/TZ in its PM2 env | new-on-10-19 | snapshot #1 | High |
| 3 | **Listeners not on 10.0.0.5:** eventopia-api `*:38001`, workers `*:9091`, grobiz-admin/landing `0.0.0.0:7016/7017` (pm2 serve), miaw-route `0.0.0.0:9001`. Only UFW keeps them off the internet | new-on-10-19 (grobiz [s027](../../../../grobiz-app-reports/session-027-2026-07-26.md) flagged 7016/7017) | snapshot #2 | High |
| 4 | **Secrets hygiene:** untracked, non-ignored `.secrets` in hoteru-technopark/bwalk; about 95 `.env*bak*` copies; pasarbesar `.env` has a malformed key-material line, and a `.env.dev` sits in that prod checkout | new-on-10-19 | snapshot #10, #18 | High |
| 5 | Stale UFW rules `7007:7008/tcp` and `3000/tcp` open to Anywhere | new-on-10-19 (rules date from s001; duitkas s001 rebound to 10.0.0.5) | snapshot #3 | Med |
| 6 | 8 procs not shipped to OpenObserve: grobiz ×4 (`~/grobiz/logs`) and miaw-flow ×4 (`~/miaw-flow-*/logs`). Nothing rotates those dirs either | new-on-10-19 | snapshot #5 | Med |
| 7 | No `max_memory_restart` on 10 procs: hoteru tpm/bwalk/radho ×6, meetgrab-api, grobiz ×4. This regresses s004's "37/37 capped" | new-on-10-19 | snapshot #14, [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md) | Med |
| 8 | TZ: 46/48 procs run in Berlin time; check any in-app schedulers before the 10-25 DST shift | new-on-10-19 | snapshot #4, registry §10 | Med |
| 9 | `foucher-admin.conf` is still disabled on proxy, pending the foucher.co renewal. admin/api.foucher.co fall into the eventopia catch-all; the `admin.foucher.co` cert (nginx installer) expires 11-20 | carried | [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md), proxy snapshot | Med |
| 10 | Repo state: untracked ecosystem files (7 apps), and pahala has both `.js` and `.cjs`. hoteru tenant configs are untracked. Prod-side code edits in teamy, pasarbesar×2, asiaweek, feyfa-wa. miaw-route runs feature branch `codex/calling-status-compatibility`. rekrutme and pahala are on detached HEADs. The `~/grobiz` checkout is behind the live release | new-on-10-19 | snapshot #9–11 | Med |
| 11 | Old 2016 RSA key (`rsa-key-20160704`) in root `authorized_keys`. It is also the only key deploy@dev accepts, so add a replacement before pruning it | carried | [s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md) #7 | Med |
| 12 | Vector double-ships ytgrab-web (Fluent Bit sends it too) and tails `ytgrab-api-*`, which has had no process since June | new-on-10-19 | snapshot #6 | Low |
| 13 | pm2-logrotate `compress=true` but 0 of 534 rotated files are gzipped | new-on-10-19 | snapshot #8 | Low |
| 14 | Failed Actions runner unit (disable it, or remove the `miaw` runner) and an empty `pm2-root.service` | new-on-10-19 | snapshot #16 | Low |
| 15 | Directus behind upstream: wagrab-admin 11.15.4, feyfa-admin 11.4.1 | carried | [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md), [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) | Low |
| 16 | Prune the old office IP `125.166.13.120` from `ignoreip`; decide how to handle the dynamic home IP | carried | [s003](../../../../app-sysadmin-reports/session-003-2026-06-08.md), eventopia s069 | Low |
| 17 | Git remotes for the local-only repos (not re-checked 10-19) | carried | [s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md) #9 | Low |

## Drift: reports vs live 10-19
| Report said | Live 10-19 shows | Source |
|---|---|---|
| "Production app server running 18 PM2 processes" | 47 apps + pm2-logrotate, all online | CLAUDE.md |
| ytgrab is a "Docker compose stack on app" | PM2 `ytgrab-web` only; no Docker | CLAUDE.md (ytgrab line) |
| Docker disabled, reversible with `systemctl enable` | `docker.sock` absent; survey reports it as not installed. s003 also lists devops in the `docker` group | [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md) |
| "Capped 37/37 PM2 apps"; `ytgrab-api` capped at 800M on app | 10 procs uncapped; ytgrab-api is no longer on app (numa+db since ytgrab s018/020), but its `.env`, Vector source and logs remain | [s004](../../../../app-sysadmin-reports/session-004-2026-06-17.md) |
| Fluent Bit ships all PM2 logs | 8 procs log outside the glob | [s002](../../../../app-sysadmin-reports/session-002-2026-05-24.md) |
| pm2-logrotate "compressed" | 0 / 534 gzipped | [s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md) |
| nginx "installed but unused" | serves `hoteru-uploads` on `10.0.0.5:8931` | [s001](../../../../app-sysadmin-reports/session-001-2026-05-12.md) M3 |
| "System Node 24 for most apps, no nvm" | true for PM2 `node`, but nvm default is 22.22.0, so an interactive `node` ≠ PM2's `node`. 6 apps run on 22 | [s005](../../../../app-sysadmin-reports/session-005-2026-07-22.md) |
| README lists 2 open follow-ups | the snapshot adds 20 anomalies (merged above) | README |
| app cannot SSH to proxy (registry) | eventopia s069 ran `fail2ban-client` on proxy from `root@app` via `10.0.0.2`. **Unresolved:** likely root can and devops can't | registry §1 vs eventopia [s069](../../../../eventopia-app-reports/session-069-2026-10-13.md) |

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 root@app 'timedatectl | grep "Time zone"; hostnamectl | grep Operating'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | tail -n +1 | wc -l; ss -tlnH | awk "{print \$4}" | sort -u'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'node -v; /usr/bin/node -v; for a in wagrab-admin feyfa-admin rekrutme pahala; do pm2 describe $a | grep -E "interpreter  "; done'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@app 'ufw status; fail2ban-client get sshd ignoreip; fail2ban-client get sshd bantime; systemctl --failed --no-legend'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@app 'ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.0.0.2 true && echo app-root-to-proxy:OK'   # settles the drift row
```
