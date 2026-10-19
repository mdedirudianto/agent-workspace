# monitor — server profile

**Stamp:** profile v1 · 2026-10-19 · sources: [registry.md](../../registry.md) (10-19), [hosts/monitor-2026-10-19.md](../../hosts/monitor-2026-10-19.md) (survey 2026-10-18T23:26Z = 10-19 06:26 WIB), [monitor-sysadmin-reports](../../../../monitor-sysadmin-reports/README.md) README + [s001]–[s011] (s008–s011 read in full), [telegram-alerts README](../../../../telegram-alerts/README.md), CLAUDE.md
**Rule:** where this profile and an older report disagree, the 10-19 snapshot wins. See **Drift**.

## Role
Monitoring and analytics hub for the cluster (`217.15.162.56` / `10.0.0.3`, Ubuntu 24.04.4, 4 vCPU, 5.8 GiB RAM, **no swap**, 96 G disk at 60 %). It runs Docker stacks for GlitchTip, OpenPanel, Uptime Kuma (+ MCP), OpenObserve and Vaultwarden, plus the Netdata parent and the `telegram-alerts` cron. Public names come in through `proxy`'s `biji-monitoring.conf`: errors., analytics., status., monitor. (nginx basic auth), vault. and observe.biji.uk. State lives on `db`: PG `glitchtip`/`openpanel`, Redis db 2/3, ClickHouse `openpanel`.
**Depends on it:** every app reporting to GlitchTip (19 projects: asiaweek, biji/miaw-route, eventopia, ytgrab/meetgrab, grobiz, pasarbesar), OpenPanel (web analytics), all Fluent Bit shippers (proxy/app/db/erp/monitor/numa/backup → OpenObserve), the fleet alert chat (Kuma, Netdata, digest) and the team password vault.

## Access
| User | How | Owns |
|---|---|---|
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor` (key-only, `PermitRootLogin prohibit-password`, `MaxAuthTries 3`) [s001] | everything: `/opt/{glitchtip,openpanel/self-hosting,uptime-kuma,uptime-kuma-mcp,openobserve,vaultwarden,telegram-alerts}`, `/etc/netdata`, `/etc/fluent-bit` |

- **fail2ban** (sshd, added in [s001]): `maxretry 5`, `findtime 10m`, `bantime 1h`, `mode aggressive`, ignoreip `10.0.0.0/22`. A bare `ssh monitor` logs in as local `dedi` and counts as a failure, so always give the user explicitly. The ban is shorter than proxy's 24 h. *The 10-19 snapshot didn't capture the jail, so re-verify.*
- **Sensitive:** monitor holds root SSH (`id_rsa`) to every cluster host over private IPs, plus the Telegram bot token (`/etc/netdata/health_alarm_notify.conf`) (telegram-alerts README). Treat a monitor compromise as fleet-wide.
- Secrets are mode 600 in compose/`.env` files [s001, s002]. Never cat them. Print names only.
- **SSH is the only public listener.** Everything else binds `10.0.0.3` or loopback (10-19).

## Services
| Kind | Unit / container | Bind | Notes |
|---|---|---|---|
| systemd | `docker`, `netdata` (v2.12.1 parent, Cloud-claimed), `fluent-bit` (v5.0.6, [s003]), `fail2ban`, `unattended-upgrades`, `cron` | netdata `10.0.0.3:19999` + 127.0.0.1 | `ModemManager` and `wpa_supplicant` are masked; `cloud-init.service` fails, which is known [s001] |
| docker | `uptime-kuma` (`louislam/uptime-kuma:2`, embedded MariaDB) | :3001 | 50 monitors, 49 active |
| docker | `uptime-kuma-mcp` (`davidfuchs/mcp-uptime-kuma:latest`) | :3200 | `status.biji.uk/mcp` |
| docker | `glitchtip-web` + `glitchtip-worker` (`glitchtip/glitchtip`, implicit latest) | :8000 | |
| docker | `op-api` / `op-dashboard` / `op-worker` (`lindesvard/openpanel-*:2.0.1-rc`) | :3333 / :3100 | bundled op-db/kv/ch services not used |
| docker | `openobserve` (`zinclabs/openobserve:latest`) | :5080 | `/opt/openobserve/docker-compose.yml` |
| docker | `vaultwarden` (`vaultwarden/server:latest`) | :8888 | |

| Schedule (server-local, CEST until 10-25, then CET) | WIB | Job |
|---|---|---|
| `7 * * * *` `/etc/cron.d/telegram-digest` → `digest.sh --scheduled` | hourly; sends **once a day at ~08:07 WIB** (01:07Z) | The gate is in WIB (≥08:00, once per WIB day), so the **10-25 DST shift doesn't move it**. cron 3.0 has no `CRON_TZ` [s011] |
| `@reboot` `/etc/cron.d/staticroute` | — | re-applies the eth0 link route [s001] |
| apt / unattended-upgrades systemd timers | timer-defined | not enumerated on 10-19, so verify live |

- The clock is **Europe/Berlin**: container and journal times are WIB −5 h now and WIB −6 h after 10-25. Normalise times in reports.

## Change procedures
| Change | Done in | Safe pattern |
|---|---|---|
| Container image update | [s009] (Kuma 2.1.3→2.4.0) | tar the named volume to `/root/kuma-backups/<name>-<date>.tgz` first · `docker compose pull && up -d` in `/opt/<stack>` · verify the version inside the container, `(healthy)`, internal + public HTTP · **then refresh `/etc/fluent-bit/container-names.lua` and restart fluent-bit**, because container IDs change on recreate [s003] · keep the tag's major (`:2`) |
| Compose port / exposure | [s001], [s002] | every mapping `10.0.0.3:<p>:<p>`, never short form (that publishes on 0.0.0.0) · back up as `docker-compose.yml.bak.<date>` · probe `http://217.15.162.56:<p>` → `000` |
| Netdata streaming / health | [s010], [s011] | `cp X X.bak-<date>` · the parent's `stream.conf` keeps `health enabled by default = no` (else duplicate child alarms) · health.d edits: `netdatacli reload-health`; stream.conf: `systemctl restart netdata` · verify recipients through the API, not the file |
| OpenObserve retention / alerts | [s005], [s006], [s008] | `PUT /api/default/streams/<s>/settings {"data_retention":N}` · **verify with `/streams/<s>/schema`**, because `GET /streams` always shows 0 [s005] · alert names: no spaces/`#?&%`/quotes [s008] · `_timestamp` alias is not allowed [s004] |
| Kuma DB edits | [s011] | `docker exec uptime-kuma mariadb … -S /app/data/run/mariadb.sock kuma` · save the before-rows + restore SQL under `/root/backup-<topic>-<date>/` · delete by exact ids only |
| telegram-alerts deploy | [s011] | edit in the workspace, then `rsync` **only** `pull.sh digest.sh digest.py`, `chown root:root` · never overwrite `ledger.jsonl`/`state.json` · `digest.sh` only with `--dry-run` unless posting is intended · no local `pull.sh` on the Mac (use `sync.sh`) |
| Package upgrade / reboot | [s001] | `apt full-upgrade`, reboot at the end of the session · afterwards check all 9 containers are up and every port is still on `10.0.0.3` |
| UFW | none yet | open item. Docker's iptables chains bypass/interact with UFW, so test on eth1 and keep an SSH session open [s001] |

## Health checks (read-only)
```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor '
  uptime; free -h; df -h /; systemctl is-active docker netdata fluent-bit fail2ban
  docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"; ss -tlnH | awk "{print \$4}" | sort -u
  for p in 3001 3100 3333 5080 8000 8888; do printf "$p "; curl -m3 -so/dev/null -w "%{http_code}\n" http://10.0.0.3:$p/; done
  curl -s "http://127.0.0.1:19999/api/v1/alarms?active" | grep -c "\"status\""
  tail -3 /var/log/telegram-digest.log; fail2ban-client status sshd | tail -2'
```
- Netdata children: `curl -s http://127.0.0.1:19999/api/v2/nodes`. Expect 6. **backup has been missing since 10-19.**
- Digest preview without sending: `cd /opt/telegram-alerts && ./digest.sh --dry-run`.

## Known noise
- SSH brute force is constant (53 failures/5 min on day one [s008]). `SSH_Brute_Force_Burst` (≥20) fires often by design.
- `1min_netdev_budget_ran_outs` WARNING on monitor is routed `silent` by stock [s011]. `streaming_never_connected` = the backup child (see follow-ups).
- ytgrab Direct/Datacenter/Residential tier canaries flap. Their Kuma notifications were detached in [s011], so a DOWN on #51 doesn't page. Use the digest and the pool aggregate.
- The ledger records every transition, including `silent` alarms: **ledger ≠ what reached Telegram** [s011]. Netdata rows before 2026-09-20 labelled CRITICAL are really WARNING [s011].
- The Kuma volume backup warns `./run/mariadb.sock: socket ignored`, which is harmless [s009]. `monitor.biji.uk` returns 400 to plain curl but works in browsers (README).

## Open follow-ups
| # | Item | Status | Source | Prio |
|---|---|---|---|---|
| 1 | **6 Kuma monitors DOWN for 2–4 months and still paging**: foucher.co (500, since 07-19), admin.foucher.co (526, since 07-22; tied to app's `foucher-admin.conf` re-enable), dev.wagrab / dev.pasarbesar (502, 08-06), dev.teamy (502, 06-28), miaw.dev.biji.uk (502, 06-17). Pause or delete the dev ones (stopped on purpose, dev rule) | new-on-10-19 | snapshot; app s005 | high |
| 2 | **OpenObserve source silent in the ledger since 2026-05-27**: either no OO alert has fired in ~5 months (unlikely given the SSH ≥20 rule) or the OO pull/creds/alerts are broken. Check `digest.sh --dry-run` output and OO alert history | new-on-10-19 | snapshot; [s008] | high |
| 3 | **Kuma coverage gaps**: no monitors for gro.biz.id app/api/admin, hoteru.uk/.co.id, avilia.id, seenow.ac, eventopia prod, rkrt.me, pahala.co, sijari.uk, baznas.duitkas | new-on-10-19 | snapshot | high |
| 4 | Rotate glitchtip/openpanel PG + ClickHouse creds (with backup's `config.sh`), Vaultwarden `ADMIN_TOKEN` and the Kuma admin password. **[s001] itself records some of these values in cleartext in git**, so redact the report as part of the rotation | carried | [s001], [s002] | high |
| 5 | OO ingest-only user: all Fluent Bit configs carry the OO admin password | carried | [s008] | med |
| 6 | Netdata child **backup never connected** (agent disabled on backup), so backup has no host metrics or alarms. Fix on backup's side | new-on-10-19 | snapshot | med |
| 7 | Pin floating images: now **4** `:latest` (openobserve 5 mo, vaultwarden 7 mo, glitchtip ×2 7 mo, mcp-uptime-kuma 10 mo). OpenPanel is on `2.0.1-rc` | carried (widened) | [s001] | med |
| 8 | UFW/nftables default-deny (UFW inactive 10-19); decide on binding sshd to eth1 only; no swap with 2.0 GiB free | carried | [s001] | med |
| 9 | ytgrab Datacenter Tier Canary missed its push window at the survey (~27 min). Recheck; not paged | new-on-10-19 | snapshot | low |
| 10 | `container-names.lua` probably stale since the Kuma recreate in [s009] and the reboot ~10-16. Check that `container_name` is filled in the `monitor` stream | new-on-10-19 (inferred) | [s003], [s009] | low |
| 11 | Clone the SSH/fail2ban OO alerts for numa's own stream · tune `App_Stderr_Spike` (≥100/5 min never fired) | carried | [s008] | low |
| 12 | Check that monitor-labelled `web_log_1m_*` dupes have stopped; check other children for the same `health … = auto` exposure | carried | [s010] | low |
| 13 | Confirm the Netdata Cloud claim is intentional (still claimed 10-19) · rotate the `monitor.biji.uk` basic-auth password | carried | [s001] | low |
| 14 | Proxy-side, raised here: add `$host` to the nginx `log_format` (unattributed 500s on `/`); nginx logrotate `size 200M` vs `daily` (error.log unrotated since 02, per registry) | carried | [s011] | low |

## Drift: reports vs live 10-19
| Report said | Live 10-19 shows | Source |
|---|---|---|
| README header: Ubuntu 24.04.2 | 24.04.4 | README, [s001] |
| Kuma "SQLite + config in the named volume" | Kuma 2 uses **embedded MariaDB** (`kuma` DB over socket); the volume is still the rollback unit | [s009] vs snapshot / telegram README |
| README: "syslog retention 30 d missed, still open" | [s006] Action 5 already set syslog to 30 d. The follow-up is likely stale; verify with the schema endpoint | README vs [s006] |
| 8 containers (s001) | 9 (openobserve added in s002). Up 2 days, host uptime 2 d 13 h: an **undocumented reboot ~10-16** | [s001], [s002] vs snapshot |
| Disk 19 G used (s001) | 58 G (60 %). Growth not explained in any session (OpenObserve data is a likely candidate) | [s001] vs snapshot |
| Pin vaultwarden + glitchtip | also openobserve + mcp on `:latest` | [s001] vs snapshot |
| fail2ban jail as in s001 | not captured on 10-19 | unverified |

## Verify live
```
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor 'timedatectl | grep "Time zone"; hostnamectl | grep Operating; uptime -s'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor 'docker ps --format "{{.Names}} {{.Image}} {{.Status}}"; ss -tlnpH'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor 'cat /etc/cron.d/telegram-digest; tail -5 /var/log/telegram-digest.log; systemctl list-timers --no-pager'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor 'fail2ban-client get sshd bantime; fail2ban-client get sshd maxretry; ufw status | head -1; free -h | grep Swap'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@monitor 'grep -n "health enabled by default" /etc/netdata/stream.conf; curl -s http://127.0.0.1:19999/api/v2/nodes | grep -o "\"nm\":\"[^\"]*\"" | sort -u'
```

[s001]: ../../../../monitor-sysadmin-reports/session-001-2026-05-19.md
[s002]: ../../../../monitor-sysadmin-reports/session-002-2026-05-19.md
[s003]: ../../../../monitor-sysadmin-reports/session-003-2026-05-24.md
[s004]: ../../../../monitor-sysadmin-reports/session-004-2026-05-25.md
[s005]: ../../../../monitor-sysadmin-reports/session-005-2026-05-25.md
[s006]: ../../../../monitor-sysadmin-reports/session-006-2026-05-25.md
[s008]: ../../../../monitor-sysadmin-reports/session-008-2026-05-25.md
[s009]: ../../../../monitor-sysadmin-reports/session-009-2026-06-22.md
[s010]: ../../../../monitor-sysadmin-reports/session-010-2026-08-20.md
[s011]: ../../../../monitor-sysadmin-reports/session-011-2026-09-20.md
