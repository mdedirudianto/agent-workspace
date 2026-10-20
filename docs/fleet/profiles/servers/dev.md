# dev — server profile

**Stamp:** profile v1 · 2026-10-19 · sources: [registry.md](../../registry.md) (10-19), [hosts/dev-2026-10-19.md](../../hosts/dev-2026-10-19.md) (live 06:36–06:40 WIB), [dev-sysadmin-reports](../../../../dev-sysadmin-reports/README.md) README + sessions 1–4, CLAUDE.md, memory *Dev host: leave stopped services stopped*, [grobiz session-037](../../../../grobiz-app-reports/session-037-2026-09-02.md). The live snapshot wins; drift is at the end.

## Role

Shared, swap-bound **dev/staging box** (`154.26.130.96`, Ubuntu 22.04.5, 4 vCPU / 5.8 GiB RAM / 8 GiB swap, 145 G disk at 76 %). Not on the `10.0.0.0/24` cluster, so it reaches the cluster only over public endpoints (e.g. `observe.biji.uk`).

- **Depends on it:** staging for hoteru (`*.dev.hoteru.uk`, campaigns), avilia (`*.dev.avilia.id` :4030), pahala (`dev.pahala.co` :7005), rekrutme (staging on `6b28451` since 2026-10-20, `dev.rkrt.me` :7007), grobiz (`dev.gro.biz.id` :7006 + docker ERPNext `erp.dev.gro.biz.id`), foucher (`api.dev.foucher.co` :8058), miaw SIP staging (docker). Also the OpenVPN server (`10.8.0.1`, UDP 1194) the Mac uses.
- **Parked here, stopped 10-19:** eventopia (`*.dev.eventopia.my`), seenow (`*.dev.seenow.ac`), wabacall (`wabacall.dev.biji.uk` :19000), asiaweek, iccn, wagrab, ytgrab, teamy, washop, miaw-api/web/route.
- **No production traffic.** Production names in dev nginx are stale (see Drift).

## Access

| User | How (from the Mac) | Owns |
|---|---|---|
| `deploy` | `ssh -o BatchMode=yes -o ConnectTimeout=15 -o IdentitiesOnly=yes -i ~/.ssh/id_rsa deploy@dev` | PM2 daemon (57 procs), `/home/deploy/*` repos and `releases/`, `~/.pm2/logs`; NOPASSWD sudo via `/etc/sudoers.d/deploy` ([s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md)); in `docker` group |
| `root` | `ssh -o BatchMode=yes -o ConnectTimeout=15 root@dev` (default identities, key only) | system services, nginx, PG 14, Redis, docker stacks, OpenVPN PKI `/etc/openvpn/easy-rsa`, fluent-bit |
| `maxbiz` | — | `erpnext-gateway` systemd unit (node, :3000) ([s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md)) |
| `sabbi`, `hopis` | password only (no keys) | old compose projects / `sim-rs-*`; owner model still undecided |

- **Key caveat (live 10-19):** the only Mac key `deploy` accepts is the **2016 RSA `rsa-key-20160704`** (`~/.ssh/id_rsa`). `~/.ssh/dev-deploy` and `~/.ssh/devops` are **refused**; docs/memory that name `dev-deploy` are wrong. s001 H6 proposed pruning this exact key: **add a replacement key first** or the Mac is locked out of `deploy@dev`.
- sshd: `PermitRootLogin without-password` (s001 set `prohibit-password`), **`PasswordAuthentication yes`** kept on purpose for sabbi/hopis, second sshd on **:2212**.
- **Ban risk:** fail2ban was installed in s001 (sshd jail on 22+2212, aggressive, **5 tries / 10 min → 1 h ban**, operator IP `125.166.13.120` + RFC1918 whitelisted). Milder than proxy's 24 h, but a few BatchMode retries with the wrong key can still ban the Mac's current IP. fail2ban state was **not captured on 10-19**; check it.
- `deploy`'s `authorized_keys`: 8 keys (s001 recorded 5), last modified 2026-10-05. root had 9+ in s001.

## Services

Clock is **WIB** (Asia/Jakarta). Server-local cron = WIB unless `CRON_TZ` is set.

| Kind | Unit / thing | Notes |
|---|---|---|
| systemd | `nginx` (45 vhosts; 80/443/8080 public, 8888 loopback) | certbot certs for `dev.*` names ([s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md)) |
| systemd | `postgresql@14-main` (PG 14.20, **127.0.0.1:5432**) | locked to localhost + `pg_hba` pruned in s001; 23 DBs, most owned by `postgres` |
| systemd | `redis-server` 6.0.16 (loopback; db0 30.8k keys, db1 6, db2 155), `mariadb` (loopback), `mongod` (loopback) | no auth on Mongo/Redis (s001 M6) |
| systemd | `openvpn@server` + `iptables-openvpn` | CA → 2034-06-21, server cert + CRL → 2036-10-05 ([s004](../../../../dev-sysadmin-reports/session-004-2026-10-08.md)) |
| systemd | `fluent-bit` 5.0.6 → OpenObserve `dev` stream, 7-day retention, HTTPS ([s002](../../../../dev-sysadmin-reports/session-002-2026-05-25.md)) | ships PM2 logs only, **not docker**; not checked 10-19 |
| systemd | `fail2ban` ([s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md)), `erpnext-gateway` (maxbiz, :3000 public) | not checked 10-19 |
| docker | grobiz ERPNext ×7 (`grobiz-erpnext-1`, mariadb, redis, worker, scheduler, socketio, nginx → 18400 loopback), `miaw-sip-staging` ×12 (asterisk, freeswitch, rtpengine, turn…), `foucher-db` (**5433 public**), `foucher-minio` | uid-1000 gunicorn/socketio in host `ps` are these containers, not a native bench (s001 correction) |
| PM2 | daemon under **`deploy`**: 57 procs, **22 online / 35 stopped by design**; `pm2-logrotate` 50M / retain 7 / compress / daily 00:00 WIB | caps (`max_memory_restart`) on 24 apps ([s003](../../../../dev-sysadmin-reports/session-003-2026-06-17.md)) |
| cron | `/etc/cron.d/openvpn-cert-check` `15 0 * * *` | s004 wrote "00:15 UTC = 07:15 WIB", but the host clock is WIB, so it most likely fires **00:15 WIB**. Syslog tag `openvpn-cert-check`; no Kuma push yet |
| swap | `/swapfile` 6 G + `/swapfile2` 2 G (pri −2, fstab), swappiness 10 | 478 MiB used on 10-19 |

## Change procedures

**PM2 restarts to reclaim swap.** Done in [s003](../../../../dev-sysadmin-reports/session-003-2026-06-17.md).
- Measure first (`free -h`, `/proc/pressure/memory`, per-process RSS + swap). PSI `full` above ~10 % means real stalls.
- Restart in **staggered batches**, fattest and oldest first. Leave freshly deployed apps warm, and don't bounce docker (the ERPNext stack is about 120 M).
- Grow swap by **adding a file** (`fallocate`, `chmod 600`, `mkswap`, `swapon`, fstab). Never `swapoff`/resize while RAM is tight.

**Stopping PM2 procs to free RAM** (e.g. before a build). Done in [grobiz s037](../../../../grobiz-app-reports/session-037-2026-09-02.md).
- Snapshot first: `pm2 jlist > ~/pm2_state_before_<x>.json`.
- **Ask before stopping anything.** The user decides which processes are live, so don't infer it from names.
- Record exactly which processes were stopped. **Leave them stopped afterwards.** They start only when needed, and never by `pm2 resurrect` or "restore all".
- Keep the `pm2-logrotate` module up.

**`max_memory_restart` caps.** Done in [s003](../../../../dev-sysadmin-reports/session-003-2026-06-17.md).
- A cap on a `bash -c`/`dotenv … sh -c` wrapper never trips, because PM2 watches the ~4 kB wrapper. Relaunch the app to exec its binary directly.
- Use `node_modules/next/dist/bin/next --interpreter node`, not the `.bin/next` shim. On rekrutme it was a shell script and crashed with a `SyntaxError`.
- The PM2 memory column is **not a liveness signal** on this host. Confirm with `pgrep -af <name>` ([s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md) H1 correction).
- Run `pm2 save` after any change.

**sshd / Postgres binding.** Done in [s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md).
- Back up to `<file>.bak.YYYY-MM-DD`.
- Run `sshd -t` before `systemctl reload ssh`, then test a fresh key login before closing the session.
- Before narrowing `listen_addresses`, sweep `/home/deploy/**/.env` for the public IP. `wagrab-admin` had `DB_HOST=154.26.130.96`.
- **Do not enable UFW**, and do not rebind apps to 127.0.0.1. Developers use direct port access (operator decision in s001, items 3b and 6).

**OpenVPN certs.** Done in [s004](../../../../dev-sysadmin-reports/session-004-2026-10-08.md).
- Back up first: `cp -a /etc/openvpn /root/openvpn-backup-<date>`.
- Renew with `EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch renew <cn>`. Easy-RSA **3.1.2** keeps the key and the CN, so client profiles don't change. 3.2 changed `renew`.
- **Always set `EASYRSA_CRL_DAYS=3650` on `gen-crl`.** The default is 180 days, and a lapsed CRL rejects every client.
- Revoke superseded serials with `revoke-renewed`. Verify with `openssl verify -crl_check`, then do a real client connect.

**Fluent Bit config.** Done in [s002](../../../../dev-sysadmin-reports/session-002-2026-05-25.md).
- Back up the conf before editing.
- dev ships to the **`dev`** stream, never `app`.
- Keep the Lua `app_name` filter.
- After restarting, check for HTTP 200 in the journal.

**Frontend builds for grobiz on dev.** Done in [grobiz s037](../../../../grobiz-app-reports/session-037-2026-09-02.md).
- Set `VITE_API_URL=https://app.dev.gro.biz.id` explicitly. `.env.production` falls back to the **production** host.
- Build sequentially, never as a parallel `pnpm -r build`, to avoid OOM.

## Health checks (read-only)

| Check | Command (as root unless noted) |
|---|---|
| Memory / swap / PSI | `free -h; swapon --show; cat /proc/pressure/memory` |
| Disk | `df -h /; du -sh /home/deploy/.pm2/logs /var/lib/docker` |
| PM2 (deploy) | `pm2 ls` · `pm2 jlist \| jq -r '.[] \| [.name,.pm2_env.status,.pm2_env.restart_time] \| @tsv'` |
| Listeners | `ss -tlnpH; ss -ulnpH` (anything on `0.0.0.0` is public, no firewall) |
| nginx | `nginx -t; ls /etc/nginx/sites-enabled \| wc -l` |
| OpenVPN | `systemctl is-active openvpn@server; journalctl -t openvpn-cert-check -n 5` |
| Logs shipping / bans | `systemctl is-active fluent-bit fail2ban; fail2ban-client status sshd` |
| Docker | `docker ps --format '{{.Names}}\t{{.Status}}'` |

## Known noise

- `tls-crypt unwrap error: packet too short` on UDP 1194 comes from internet scanners, not clients ([s004](../../../../dev-sysadmin-reports/session-004-2026-10-08.md)).
- SSH password brute force is constant (5.7k failures per log rotation in s001). fail2ban bans within seconds.
- 35 stopped PM2 procs are expected. `pasarbesar` shows 542 restarts from before it was stopped.
- Low "free" RAM after restarts is healthy (buff/cache). Judge memory by available RAM and PSI.
- One synthetic `EXPIRING` `user.crit` line at 2026-10-08 21:54:51 WIB came from the s004 negative test.
- Wrapper-launched apps show about 2–4 kB RSS in `pm2 ls`. The real child process holds the memory.

## Open follow-ups

| # | Item | Status | Source | Priority |
|---|---|---|---|---|
| 1 | Add a replacement Mac key to `deploy` (and root), fix docs/memory naming `dev-deploy`, *then* prune `rsa-key-20160704` | new-on-10-19 (key finding) / carried (H6 prune deferred) | [s001](../../../../dev-sysadmin-reports/session-001-2026-05-17.md) item 7, snapshot | **High** |
| 2 | Public, unfirewalled binds: **foucher-db PG container :5433**, foucher-api :8058, docker 9001/9010/5061, 3000, 8000, 9000. Bind the DB container to loopback at minimum (UFW stays off by decision) | new-on-10-19 (5433/8058/SIP) / carried (8000/9000/3000, s001 C4/H3) | snapshot; s001 | **High** |
| 3 | Wire `openvpn-cert-check` into Uptime Kuma (push monitor via public `status.biji.uk`, `KUMA_PUSH_URL` in `/etc/default/openvpn-cert-check`); needs a write on `monitor` | carried | [s004](../../../../dev-sysadmin-reports/session-004-2026-10-08.md) | Med |
| 4 | Remove production hoteru names (`hoteru.uk`, `www`, `demo`, `public`, `manage`) from dev nginx | carried (present since s001) / re-flagged 10-19 | s001 nginx table, snapshot | Med |
| 5 | Disk 50 G used (May) → **104 G (76 %)**. Find the growth (docker SIP images/volumes, PM2 logs, `releases/`) before it pinches | new-on-10-19 | snapshot vs s001 | Med |
| 6 | `PasswordAuthentication yes` + second sshd :2212. Decide the sabbi/hopis/maxbiz account model, then go key-only and use one port | carried | s001 items 4, 13, H7 | Med |
| 7 | Remove `/root/openvpn-backup-2026-10-08` (holds CA + server keys) and the `.ovpn` copies in Mac `~/Downloads/openvpn-dev/` (Downloads is analyse-only for Claude, so the user deletes them) | carried | s004 | Low |
| 8 | Ship docker container logs (grobiz ERPNext, SIP) to OpenObserve; build a "Dev Overview" dashboard | carried | [s002](../../../../dev-sysadmin-reports/session-002-2026-05-25.md) | Low |
| 9 | Move `feyfa-voucher` (`astro dev`) and `feyfa-admin` (`directus start`) to production builds; relaunch wrapper apps to direct exec if they leak; RAM bump is the real fix | carried | [s003](../../../../dev-sysadmin-reports/session-003-2026-06-17.md) | Low |
| 10 | Git remotes on local-only repos (24/25 lacked `origin` in May). Re-check, since several now deploy from `releases/` | carried | s001 M1 / item 10 | Low |
| 11 | OpenVPN **CA expires 2034-06-21**. Renewing it means reissuing every profile | carried | s004 | Low (long-dated) |

## Drift: reports vs live 10-19

| Report said | Live 10-19 shows | Source |
|---|---|---|
| Mac reaches `deploy@dev` with `~/.ssh/dev-deploy` (docs/memory) | `dev-deploy` **refused**, never in `authorized_keys`; only `~/.ssh/id_rsa` (2016 RSA) works | snapshot Access |
| `deploy` has 5 authorized keys | 8 keys (mod 2026-10-05) | s001 vs snapshot |
| PG exposure fixed: only `127.0.0.1:5432` | native PG 14 is loopback, but a **Postgres container `foucher-db` listens publicly on :5433** | s001 item 5 vs snapshot |
| Docker = grobiz ERPNext ×7 only | + `miaw-sip-staging` ×12, `foucher-db`, `foucher-minio` | s001 vs snapshot |
| 27–38 PM2 apps, all online after s003 | 57 procs, **22 online / 35 stopped** (grobiz s037 stop-all, by design) | s003 vs snapshot |
| CLAUDE.md: eventopia, seenow, wabacall "run on dev" | all three **stopped** on dev | CLAUDE.md vs snapshot |
| cloudflared tunnels (`iccn-tunnel`, `wabacall-tunnel`, `hoteru-tunnel-*`) under PM2 | cloudflared **not running** | s001/s002 vs snapshot |
| Swap 1.5 G used after s003 (5.2 G before) | 478 MiB used of 8 G, 1.3 GiB RAM available | s003 vs snapshot |
| Disk 50 G used after s001 cleanup | 104 G used (76 %) | s001 vs snapshot |
| Cert-check cron "00:15 UTC = 07:15 WIB" | host TZ is WIB, so `15 0` = 00:15 WIB unless `CRON_TZ` is set. Verify | s004 vs snapshot/clock |
| fail2ban installed + active, Fluent Bit active | not captured in the 10-19 survey (unknown, not contradicted) | s001/s002 |
| CRL lapse risk (180 d default) | closed: CRL nextUpdate 2036-10-05 | s004, confirmed |

## Verify live

```bash
# deploy (PM2) — only id_rsa works
ssh -o BatchMode=yes -o ConnectTimeout=15 -o IdentitiesOnly=yes -i ~/.ssh/id_rsa deploy@dev 'pm2 ls'
# root (system reads)
ssh -o BatchMode=yes -o ConnectTimeout=15 root@dev 'timedatectl | grep "Time zone"; free -h; df -h /; ss -tlnH | awk "{print \$4}" | sort -u'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@dev 'ufw status; systemctl is-active fail2ban fluent-bit openvpn@server nginx postgresql@14-main; fail2ban-client status sshd'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@dev 'docker ps --format "{{.Names}}\t{{.Ports}}"; cat /etc/cron.d/openvpn-cert-check'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@dev 'sshd -T | grep -Ei "^(port|permitrootlogin|passwordauthentication)"; grep -lE "hoteru\.uk" /etc/nginx/sites-enabled/*'
```
