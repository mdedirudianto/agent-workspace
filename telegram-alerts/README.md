# Telegram Alert Ledger

A local, read-only aggregator that pulls "everything that has been sent to Telegram" across the fleet into one file, so alerts can be checked on request instead of being copy-pasted from the Telegram chat.

All sources below post to the **same Telegram chat ID `293832479`** — this tool exists because that chat is otherwise the only record of what fired.

## Sources

| Source | Host | Triggers | Mechanism | History |
|---|---|---|---|---|
| **Uptime Kuma** | `monitor` (embedded MariaDB, `docker exec uptime-kuma mariadb ... -S /app/data/run/mariadb.sock kuma`) | 9 monitors: `youtubegrab.com`/`YouTubeGrab Health` (http/keyword), `meetgrab.us`/`MeetGrab API Health` (http/keyword), and 5 **push**-type canaries (`ytgrab Download Canary`, `MeetGrab Summary Canary`, `ytgrab Direct/Datacenter/Residential Tier Canary`) | `heartbeat` table, `important=1` rows are exactly the down/up transitions Kuma notifies on. Canaries are external cron scripts (`~/ytgrab-download-canary.sh` on `app`+`numa`, `~/meetgrab-summary-canary.sh` on `app`) that run the real functional test and report `up`/`down` to Kuma's push endpoint (`http://10.0.0.3:3001/api/push/<token>`) — their result lands in `heartbeat` exactly like any other monitor. | Full — queried directly. |
| **OpenObserve** | `monitor`, reachable at `https://observe.biji.uk` from anywhere (no SSH tunnel needed) | 4 scheduled SQL alerts: `SSH_Brute_Force_Burst`, `Fail2ban_IP_Ban`, `Nginx_5xx_Spike`, `App_Stderr_Spike` (see `monitor-sysadmin-reports/session-008-2026-05-25.md`) | `GET /api/v2/default/alerts` (Basic Auth) — this OO instance's alerts API is v2 (folder-scoped), not the plain `/api/{org}/alerts` path some OO docs show | Partial — the API exposes `last_satisfied_at` per rule, not a full trigger log. Each pull records a new event only when that timestamp advances past the stored checkpoint. Can't backfill triggers from before this tool existed. **Not** `last_triggered_at` — that field advances on every scheduled evaluation (every 5min here) regardless of whether the condition was met, since it also covers real-time/streaming alerts; `last_satisfied_at` only advances when the condition was actually true, i.e. when it really fired to Telegram (confirmed live 2026-08-03: all 4 alerts shared one `last_triggered_at` value that moved by exactly 5min between two polls, while `last_satisfied_at` was `null` on 3 of 4 and held a real May 2026 date on the 4th). |
| **Backup notify.sh** | `backup` | Any backup job failure (wagrab, tier2/3, erp-bench, grobiz) | `/opt/backup/notify.sh`'s `notify()` writes `[ALERT] <YYYY-MM-DD HH:MM WIB> <msg>` to `/var/log/backup.log` *before* calling Telegram | Full — the log already has history back to whenever the file started. |
| **Netdata health alarms** | `app`, `db`, `proxy`, `erp`, `monitor` | swap/OOM/disk/CPU/load thresholds (see `app-sysadmin-reports/session-004-2026-06-17.md`) | `health_alarm_notify.sh` → Telegram | Full — Netdata's HTTP API only exposes current alarm state, not history, but each host keeps its own history in a local SQLite DB (`/var/cache/netdata/netdata-meta.db`, tables `health_log`/`health_log_detail`), queried read-only per host via `python3`'s built-in `sqlite3` module (no `sqlite3` CLI binary on these hosts). |

## Where it runs

**On `monitor`, `/opt/telegram-alerts/`, from cron** (moved off the Mac on 2026-09-20 so it no longer depends on a laptop being on). `monitor` already had root SSH (`id_rsa`) to every cluster host, holds the Kuma DB locally, and holds the Telegram bot token. `pull.sh` runs commands locally for `monitor` and over SSH to private IPs (`10.0.0.x`) for the others; `rsh`/`epoch_iso` in `pull.sh` keep it portable between Linux and macOS.

- The **ledger and checkpoints on `monitor` are authoritative.** Running `pull.sh` on the Mac is refused (it would fork the checkpoints); use `./sync.sh` to fetch the current ledger, or `PULL_LOCAL=1 ./pull.sh` to force.
- Deploy a change: edit here, then `rsync -a pull.sh digest.sh digest.py root@monitor:/opt/telegram-alerts/ && ssh root@monitor 'chown -R root:root /opt/telegram-alerts'`. (Don't overwrite `ledger.jsonl`/`state.json` on `monitor`.)
- OpenObserve creds: a copy of `~/.config/telegram-alerts/.env` (mode 600) lives on `monitor` at `/root/.config/telegram-alerts/.env`.

## Files

- `pull.sh` — the aggregator. Safe to re-run: each source has its own checkpoint in `state.json`, so a run only fetches events newer than the last pull. Every remote call is read-only.
- `digest.sh` / `digest.py` — daily summary sender (see **Daily digest** below). `digest.sh` runs `pull.sh` first, then `digest.py` builds and sends one message.
- `sync.sh` — copies the authoritative `ledger.jsonl` + `state.json` from `monitor` down to this checkout (one-way).
- `ledger.jsonl` — append-only, one JSON object per line, newest appended at the bottom:
  ```json
  {"ts": "2026-08-02T17:10:30Z", "source": "kuma", "monitor": "ytgrab Datacenter Tier Canary", "status": "down", "msg": "IP_LOCK_FAILED ranged fetch returned 403"}
  {"ts": "2026-08-02T20:00:00+07:00", "source": "backup", "host": "backup", "msg": "Backup verify FAILED: grobiz-site:59aba5d4.gro.biz.id"}
  {"ts": "2026-08-02T23:03:35Z", "source": "openobserve", "alert": "Nginx_5xx_Spike", "last_satisfied_at": "1785695107855694"}
  {"ts": "2026-07-30T04:46:20Z", "source": "netdata", "host": "db", "alarm": "postgres_db_transactions_rollback_ratio", "chart": "postgres_local.db_wagrab_transactions_ratio", "status": "CRITICAL", "msg": "PostgreSQL DB wagrab aborted transactions"}
  ```
  `ts` is always normalized to ISO-8601 with an explicit UTC (`Z`) or WIB (`+07:00`) offset, matching whatever timezone the source itself used.
- `state.json` — per-source checkpoint. Delete a key (or the whole file) to force a re-pull/backfill from that source's full available history.

## Netdata status codes

`status` in netdata ledger rows is one of `WARNING`, `CRITICAL`, `CLEAR` — mapped from netdata's internal `RRDCALC_STATUS` codes (`-2` REMOVED, `-1` UNDEFINED, `0` UNINITIALIZED, `1` CLEAR, `3` WARNING, `4` CRITICAL on Netdata v2.x). **Fixed 2026-09-20:** earlier versions mapped `3` to CRITICAL and never pulled `4`, so netdata rows pulled before that date labelled `CRITICAL` are really WARNINGs and real CRITICALs are missing. The ledger also records **every** transition, including alarms routed `to: silent` (e.g. `ml_*`, `tcp_resets`, `netdev_*`, `plugin_data_collection_status`) — those never reached Telegram. The pull query only selects transitions *into* WARNING/CRITICAL, or *into* CLEAR from WARNING/CRITICAL (a recovery) — this matches what actually reaches Telegram and excludes the high-volume UNINITIALIZED/REMOVED churn that happens on every netdata restart or chart re-init.

## Credentials

The OpenObserve pull needs Basic Auth creds. They are **not** stored in this repo — `pull.sh` sources `~/.config/telegram-alerts/.env` (outside the git tree) if present:

```sh
OO_USER="..."
OO_PASS="..."
```

If that file is missing, `pull.sh` skips the OpenObserve source with a warning rather than failing the whole run.

## Usage

```sh
./pull.sh
```

On the Mac use `./sync.sh` instead (see **Where it runs**); on `monitor` run this, then read the newly appended tail of `ledger.jsonl` for a summary of what fired since the last check. Any actual remediation (restart a service, raise a threshold, patch a canary script) still goes through the normal per-step approval process — this tool only closes the "what happened" visibility gap.

## Daily digest

One Telegram message a day, 08:00 WIB, summarising everything since the previous digest (default 24h, capped at 48h so a sleeping Mac catches up). Exists because noisy WARNING-class alarms were moved out of live paging on 2026-09-20 (see `monitor-sysadmin-reports/session-011-2026-09-20.md`) — the digest is where they still show up.

| Section | Content |
|---|---|
| 🔎 Needs a look | Alarms/monitors still open, CRITICAL episodes, Kuma downs, backup failures, OpenObserve triggers |
| 📉 Digest-only | Alarms no longer paged live: proxy `web_log_1m_{bad_requests,redirects,unmatched}`, db `postgres_db_transactions_rollback_ratio` / `postgres_acquired_locks_utilization`, the 3 ytgrab tier canaries — episode counts + longest duration |
| 📨 Already paged live | Compact counts of what was sent individually |
| 🔇 Never paged | Transition count for stock-`silent` alarms (`ml_*`, `tcp_resets`, `netdev_*`, `plugin_data_collection_status`) |

- **Sending:** `digest.py` posts with the Netdata bot token in `/etc/netdata/health_alarm_notify.conf` — directly on `monitor`; if run elsewhere it SSHes to `monitor`. No bot token is stored on the Mac.
- **Scheduling:** `/etc/cron.d/telegram-digest` on `monitor` runs `digest.sh --scheduled` at minute 7 of **every hour**. The script exits silently unless it is ≥ 08:00 WIB and no digest has gone out yet that WIB day, so the digest lands ~08:07 WIB. This is DST-proof (the host is on Europe/Berlin and this cron has no `CRON_TZ`) and self-healing: if `monitor` was down or Telegram failed at 08:07, the window doesn't advance and the next hourly run retries. Log: `/var/log/telegram-digest.log` (one line per real run). **No digest by ~09:00 = check that log.** The old Mac launchd agent was removed.
- **Window state:** `state.json` key `digest.last_end`; advanced only after Telegram confirms delivery.
- **Data-gap warning:** anything `pull.sh` prints other than `pulled N events` / `no new events` is surfaced at the top of the message.
- On `monitor`: `./digest.sh --dry-run` refreshes the ledger and prints the message without sending or moving the window (`DIGEST_TEST_HOUR=8 ./digest.sh --scheduled --dry-run` on a scratch copy exercises the cron gate). On the Mac: `./sync.sh && python3 digest.py --dry-run --hours N` previews any window.
- **Keep the alarm lists in `digest.py` in sync** (`SILENT_STOCK`, `DIGEST_ONLY_NETDATA`, `DIGEST_ONLY_KUMA`) whenever an alarm is silenced or re-enabled in Netdata/Kuma.
- Ledger rows with `"backfill": true` were added on 2026-09-20 to recover Netdata status-4 (CRITICAL) events the old `pull.sh` never pulled (last 72h only).
- Disable: delete `/etc/cron.d/telegram-digest` on `monitor`.

## Known noise

The per-tier ytgrab canaries (`Direct`/`Datacenter`/`Residential`) push to Kuma every 5 minutes and flip `important` on nearly every cycle due to how Kuma's push-monitor "expected heartbeat window" interacts with cron jitter — expect frequent up/down pairs from these three monitors in the ledger. This is real signal (not a bug in this tool) but is high-volume; nothing is filtered out, per the workspace's no-silent-caps convention, but keep it in mind when scanning the tail.
