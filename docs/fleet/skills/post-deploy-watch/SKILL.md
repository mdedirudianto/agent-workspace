---
name: post-deploy-watch
description: Use right after a production deploy or restart on the biji fleet, or when the user asks "is it ok?", "keep an eye on it", "anything wrong since the deploy?" about a running app.
---

# Post-deploy watch

**Core principle:** every check here is read-only, so **run them now**. Don't ask whether to run them, and don't hand the user a list. Two passes at different times beat one snapshot.

## Sources (all read-only)

Use the SSH forms in `docs/fleet/registry.md`. The process names, ports, health paths and **Known noise** come from `docs/fleet/profiles/<app>.md`.

| Source | Command / place | Problem if |
|---|---|---|
| PM2 | `pm2 jlist` → status, `restart_time`, uptime per process | restarts grow between passes (crash loop shows `online`) |
| Origin | `curl` the private health endpoint on `10.0.0.5:<port>` | not 200, or much slower than before |
| Public | each domain in the profile through Cloudflare | unexpected code. An expected 401/301 is fine |
| Error logs | `tail -n 300 ~/.pm2/logs/<name>-error.log` | new error *kinds* since the flip, not lines that were there before |
| OpenObserve | stream `app`. **grobiz and miaw-flow logs aren't shipped**, so tail their files directly | |
| GlitchTip | the app's project on monitor | new issues since the flip |
| Kuma / alerts | `telegram-alerts/sync.sh` then `jq` the ledger for the app | an open DOWN with no matching UP |
| proxy | `tail /var/log/nginx/error.log` grep the upstream port | `connect() failed`, `upstream prematurely closed` |
| Data | the profile's queue/Redis/DB signals (e.g. Redis db keys, a queue backlog) | 0 keys where traffic is expected, a stuck backlog |

**Time zones:** PM2 logs on `app` and `erp` are Europe/Berlin (CEST until 2026-10-25, then CET). db and proxy are WIB. Convert the flip time into each host's clock before filtering. Report in WIB.

## Cadence

- **Pass 1, immediately:** baseline everything, and note the restart counts and the error-log line counts.
- **Pass 2, after about 5 min:** compare with pass 1.
- **"Keep an eye on it for N":** add passes at about 15 and 30 min, then at the end (use `ScheduleWakeup` or Monitor, not a foreground sleep).
- Also look at the parts the deploy did **not** touch: workers, static SPAs on proxy, and other instances. If they now depend on changed code, they're stale.

## What to do with a problem

- Report it at once with the evidence (log lines, codes) and a proposed fix.
- A restart or rollback is a write step, so ask first. Have the exact command ready.
- Never "fix" by restarting during the watch.

## Report

Answer in one line ("OK: 3/3 online, restarts flat, 7/7 hosts 200, no new GlitchTip issues, 2 passes 10:07/10:12 WIB"), or name the failure. Record the passes in the session report's Verification table.
