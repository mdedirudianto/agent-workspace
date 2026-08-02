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

## Files

- `pull.sh` — the aggregator. Safe to re-run: each source has its own checkpoint in `state.json`, so a run only fetches events newer than the last pull. Every remote call is read-only.
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

`status` in netdata ledger rows is one of `WARNING`, `CRITICAL`, `CLEAR` — mapped from netdata's internal `RRDCALC_STATUS` codes (`-2` REMOVED, `-1` UNDEFINED, `0` UNINITIALIZED, `1` CLEAR, `2` WARNING, `3` CRITICAL). The pull query only selects transitions *into* WARNING/CRITICAL, or *into* CLEAR from WARNING/CRITICAL (a recovery) — this matches what actually reaches Telegram and excludes the high-volume UNINITIALIZED/REMOVED churn that happens on every netdata restart or chart re-init.

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

Run this, then read the newly appended tail of `ledger.jsonl` for a summary of what fired since the last check. Any actual remediation (restart a service, raise a threshold, patch a canary script) still goes through the normal per-step approval process — this tool only closes the "what happened" visibility gap.

## Known noise

The per-tier ytgrab canaries (`Direct`/`Datacenter`/`Residential`) push to Kuma every 5 minutes and flip `important` on nearly every cycle due to how Kuma's push-monitor "expected heartbeat window" interacts with cron jitter — expect frequent up/down pairs from these three monitors in the ledger. This is real signal (not a bug in this tool) but is high-volume; nothing is filtered out, per the workspace's no-silent-caps convention, but keep it in mind when scanning the tail.
