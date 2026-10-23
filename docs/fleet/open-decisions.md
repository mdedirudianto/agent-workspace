# Open decisions

**Opened:** 2026-10-19, from the live fleet survey ([hosts/](hosts/)) and the profile drafting. **Rule:** nothing here is acted on without the user's go, and each item becomes its own approved session. When an item is decided, move it to **Decided** with the date and the session that carried it out.

Priority: **P1** = exposure or data-loss risk, do soon. **P2** = reliability or monitoring gap. **P3** = hygiene.

## Security

| ID | P | Finding | Evidence | Options / recommendation |
|---|---|---|---|---|
| S1 | P1 | **Plaintext credentials in committed reports:** db S001 (old MariaDB root), monitor S001 (service passwords), backup S001 (Postgres password, part of the Telegram bot token), asiaweek S002 (prod Postgres password), miaw-route S001/S002 (seed admin key, verify token, OpenObserve token). seenow S005 has a dev-only QA seed password | `ops-redact` fired on each file while reading | Rotate each credential, then redact the reports in a new commit. History still holds the old values, but those are dead after rotation. A history scrub is a separate, explicit decision (it rewrites pushed history) |
| S2 | P1 | **db SSH is open to the world:** password auth on, root login allowed, no fail2ban. Redis, Mongo and ClickHouse have no auth and rely on UFW alone. phpMyAdmin, pgAdmin4 and mongo-express are public through CF at `db.biji.uk`. `pg_hba` has a public `/21` line | [servers/db](profiles/servers/db.md) | Key-only SSH plus fail2ban (as on the other hosts). Put the admin UIs behind Cloudflare Access or remove them. Drop the public `pg_hba` line |
| S3 | P1 | **dev has no firewall** (UFW inactive), password SSH on, a Postgres container public on `:5433`, foucher-api `:8058`, SIP ports and 3000/8000/9000 open | [servers/dev](profiles/servers/dev.md) | Enable UFW with an allow-list (22, 80, 443, 1194/udp, the SIP ports only if needed). Key-only SSH |
| S4 | P1 | **`.git/` publicly served** on biji.uk and biji.co.id | [servers/proxy](profiles/servers/proxy.md) | `location ~ /\.git { deny all; }` in those vhosts, or remove the `.git` dirs from the web roots |
| S5 | P2 | **proxy catch-all:** eventopia's `server_name ~^.+$` takes every unknown name on :443, including `<tenant>.seenow.ac`. Unknown names on :80 get 200 | [servers/proxy](profiles/servers/proxy.md), [seenow](profiles/seenow.md) | Narrow the eventopia regex to its custom-domain list (or a map), and add a real `default_server` 444 for :443 with SNI and for :80 |
| S6 | P2 | **app listeners on all interfaces:** eventopia-api `*:38001`, workers `*:9091`, grobiz-admin/landing `0.0.0.0:7016/7017`, miaw-route `0.0.0.0:9001`. Stale UFW rules `7007:7008` and `3000` are open to Anywhere | [servers/app](profiles/servers/app.md) | Bind to `10.0.0.5` (or 127.0.0.1) and delete the stale UFW rules |
| S7 | P2 | **Secrets lying around on app:** untracked `.secrets` in the hoteru technopark and bwalk trees, about 95 `.env*bak*` copies, eventopia `.env` (fixed to 600 in eventopia S072; the two old `env-pre-*` copies were deleted 2026-10-23, `env-pre-b35dfb70-*` stays for about a week) | [servers/app](profiles/servers/app.md), [eventopia](profiles/eventopia.md) | Move or delete per file after checking, `chmod 600` every `.env` |
| S8 | P2 | **monitor credential rotation** still open: GlitchTip, OpenPanel and ClickHouse DB passwords, Vaultwarden `ADMIN_TOKEN`, Kuma admin | monitor S001/S002 | One rotation session (overlaps with S1) |
| S9 | P2 | **avilia:** all 117 synced affiliate logins share one default password | [avilia](profiles/avilia.md) | Force a reset on first login, or issue per-affiliate passwords |
| S10 | P1 | **Anthropic API key from 2026-09-06** (`sk-ant-api03…`) seen in the ecc logs, which are now redacted | session of 2026-10-19 | **User item:** revoke it in the Anthropic console |

## Reliability and monitoring

| ID | P | Finding | Options / recommendation |
|---|---|---|---|
| R1 | P1 | **backup:** no offsite copy and no encryption (197G on one VPS, 191G of it wagrab). Redis isn't backed up at all, including eventopia db6, which holds Redis-only state. ClickHouse and monitor's Docker volumes aren't either | restic to an offsite bucket (it covers encryption too). Add a Redis RDB pull for db6 at least |
| R2 | P1 | **`grobiz-wasessions` pull failed** 10-14, 10-15 and 10-18. These are Baileys credentials, which can't be re-issued | Diagnose the pull (timeout or size), with a read-only look first |
| R3 | P2 | **Uptime Kuma:** 6 monitors down for 2–4 months that still page (foucher.co 500, admin.foucher.co 526, four dev 502s). Most prod apps have no monitor: grobiz, hoteru, avilia, seenow, eventopia, rkrt.me, pahala, sijari, duitkas | Pause or delete the dead ones. Add monitors per the observability matrix (analysis §5.11) |
| R4 | P2 | **telegram-alerts:** no OpenObserve entries since 2026-05-27 | `digest.sh --dry-run` plus the pull log on monitor |
| R5 | P2 | **seenow workers on Redis db 0** (not db 7) with 35.8k retained completed jobs, about +288/day | Code fix: keep the db index in the BullMQ connection and set `removeOnComplete`. Then clean up db 0 by exact pattern |
| R6 | P2 | **ClickHouse `system` logs at 71.5 GiB** with no TTL (about 54 GiB of it `trace_log` + `text_log`) | Add TTLs in the server config, then truncate the old parts |
| R7 | P2 | **app process limits and logs:** ytgrab-web has restarted 57 times at its 500M cap. 10 processes have no `max_memory_restart`. grobiz and miaw-flow logs aren't shipped. logrotate isn't compressing | Raise or fix the ytgrab cap, add limits, extend the fluent-bit globs, fix pm2-logrotate compression |
| R8 | P2 | **db and dev:** db had 257 packages pending, uptime 396 days, never upgraded; the provider power-off on 2026-10-19 restarted it but the kernel is still 5.15.0-142 with 252 pending (184 security). dev: kernel 5.15.0-170, 120 pending (70 security). Neither has unattended-upgrades | A planned maintenance window with a reboot (db takes every app down, about 20 min of 5xx on 10-19). Install unattended-upgrades without auto-reboot on both |
| R9 | P2 | **erp:** hrms on a detached HEAD (`aa42d57`). 3 newer tenant sites need checking for hrms, the scheduler and the TZ. **DST on 2026-10-25** moves app, erp and monitor cron and log offsets to WIB − 6 h | Pin hrms to a branch or tag, check the 3 sites, note the DST shift in the reports |
| R10 | P2 | **dev access:** the Mac reaches `deploy@dev` only with `~/.ssh/id_rsa` (2016 RSA), which dev S001 proposed to prune | Add an ed25519 key for deploy first, then prune |
| R11 | P3 | **Two certbots on proxy** (apt timer + snap timer). ~~On app the snap renew unit has failed~~ (cleared 2026-10-20: the expired `api.wagrab.com` renewal conf was moved aside, [backup S006](../../backup-sysadmin-reports/session-006-2026-10-20.md)) | Keep the apt one and remove snap certbot after checking which owns which lineage |
| R12 | P2 | **Netdata on backup** is installed but disabled, so backup has no host metrics or disk alarms | Enable it and stream to monitor |
| R13 | P2 | **No monitor on a single ytgrab backend.** numa's `ytgrab-api` was down about 14.5 h on 2026-10-19/20 and nothing alerted, because the LB hid it and the tier canaries go through the public API. Only the `Download Canary` push heartbeat flagged it | Add Kuma HTTP monitors on `http://10.0.0.7:7009/api/v1/health` and `http://10.0.0.1:7009/api/v1/health` (60 s, retries 2). The Kuma MCP can't create monitors, so this is a UI step. [backup S006](../../backup-sysadmin-reports/session-006-2026-10-20.md) |
| R14 | P2 | **backup jobs aren't interruption-safe.** A shutdown during `wagrab-pg.sh` leaves a truncated dump at the final filename, and the sequential `backup.sh` then skips every later job for that day | Dump to `*.dump.tmp` and `mv` on success; run each job independently of the previous one; alert if a day's expected files are missing |
| R15 | P2 | **eventopia audit-chain alarm fires every 10 min and hides the rest of the chain.** `operator_audit_log` seq 56 (the only `audit.export`, 2026-07-10) fails `row_hash_mismatch`. It predates writer fix `2be3f840` (2026-08-08), which needs no backfill, so it never clears. A full recompute on 2026-10-23 shows the other 534 rows and all 535 `prev_hash` links are fine, but `verifyChain` returns at the first break, so a real break after seq 56 would be invisible | (a) leave it; (b) **recommended:** change the verifier in the eventopia repo to record a documented known-break (seq 56) and keep verifying past it, so the alarm means something again, with row 56 untouched; (c) re-seal row 56 (rewrites a security log, not recommended). [eventopia S072 addendum](../../eventopia-app-reports/session-072-2026-10-21.md) |
| R16 | P1 | **The provider's private network keeps dropping single hosts and nothing alerted us.** `app` was isolated 2026-10-23 05:51 → ~07:20 WIB (~1 h 30 min, every app-backed site 502, found by the user at 06:53); `db` 2026-10-22 05:55–09:31; `monitor` flapped 10-21 22:53; `app` flapped 10-21 11:04. All after the 10-19 provider reboot wave. A guest `eth1` bounce and a guest reboot did not help; only a provider-panel shutdown + start did ([app s007](../../app-sysadmin-reports/session-007-2026-10-23.md), [grobiz s070](../../grobiz-app-reports/session-070-2026-10-23.md)) | **Owner:** open a provider ticket for the private NIC ports of app/db/monitor with the capture evidence in s007. **Alerting was checked 2026-10-23:** Kuma and Netdata detected the `app` outage within ~1 min (Kuma DOWN for 17 monitors from 05:51:30 WIB, `Telegram — Dedi` attached; delivery is unverifiable server-side, so confirm in the chat). Consider one aggregated private-IP probe from `proxy` to an `app` upstream plus a Kuma resend interval, so a single alert stands out from the burst. Re-measure `app`/`monitor` latency (jittery after recovery) |
| R17 | P3 | **ytgrab thumbnails: Cloudflare doesn't cache `/_next/image`** (`cf-cache-status: DYNAMIC`), so every thumbnail hits `app`. Image disk cache is now capped at 256 MiB (web `fc9f7a1`, ytgrab S043) after an uncapped one hung thumbnails ~17 min after a cold boot. | [ytgrab S043](../../ytgrab-app-reports/session-043-2026-10-23.md) | Optional CF cache rule for `/_next/image`; if added, `maximumDiskCacheSize: 0` could drop the boot scan entirely. Also still open there: re-publish userscript 1.0.1 on Greasy Fork, confirm the cache stays ≲ 256 MiB and time one cold restart |

## Hygiene

| ID | P | Item |
|---|---|---|
| H1 | P3 | 16 stale `.prev` / `.bak*` rollback dirs on proxy (keep the newest per site; the 4 eventopia-checkin `bak-*` were deleted 2026-10-23, so about 12 remain, not re-counted). Leftover `verify_wagrab_484379` DB on db. 75G of SIP test files in `/var/tmp` and 22G of SIP-lab images on backup. `/var/log/backup.log` has no logrotate. proxy `error.log` hasn't rotated since 2026-02 |
| H2 | P3 | Missing or stale reports: the miaw-route redeploy of 2026-10-15 has no report; the asiaweek README only shows the dev footprint; the proxy README's later edits are recorded only in app reports |
| H3 | P3 | Heads-up: pahala's next release replaces Midtrans with Xendit QRIS (2 migrations, one renames `midtrans_txn_id`). Treat it as a payment-provider migration, not a routine deploy |

## In progress

| Item | State |
|---|---|
| eventopia `PIN_PEPPER_PREVIOUS` retirement | After S071 the old (exposed) pepper still verifies the 16 pre-rotation PINs until each is re-hashed at sign-in. Later: clear the remaining ones to "not set" by exact IDs, remove `PREVIOUS`, restart the api (needs a go) |

## Decided

| Date | Item | Carried out in |
|---|---|---|
| 2026-10-19 | eventopia `PIN_PEPPER` rotation, lock-out-free via `PIN_PEPPER_PREVIOUS` | [eventopia S071](../../eventopia-app-reports/session-071-2026-10-19.md) |
| 2026-10-19 | certbot deploy hook on proxy (reload nginx after renewal) | [proxy S008](../../proxy-sysadmin-reports/session-008-2026-10-19.md) |
| 2026-10-18 | eventopia prod DB password rotation | [eventopia S070](../../eventopia-app-reports/session-070-2026-10-18.md) |
