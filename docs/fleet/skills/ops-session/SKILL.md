---
name: ops-session
description: Use when writing or updating a session report in the /Users/dedi/Operations workspace - after server or app work, including ops work done from an app repo's own session, or when the user says "log this", "write the session", "commit this session".
---

# Ops session report

**Core principle:** the report is the history. Times are normalised, secrets never appear, and incidents and leftovers are named even when the user shrugs them off.

## Where

- Subject is one server → `<server>-sysadmin-reports/`. Subject is one app touching several hosts → `<app>-app-reports/`.
- Number = the highest `session-NNN` in that dir + 1. File `session-NNN-YYYY-MM-DD.md`.
- Work run from an app repo's own Claude session **still** gets a report here.
- Match the most recent session's layout in that dir.

## Content contract (in order)

1. `# Session N — <topic>`, plus `**Date:**` and the server or app header fields that dir uses.
2. One-paragraph summary: what changed, from SHA to SHA, and the outcome.
3. **Window in WIB**, with the source clock named. app, erp and monitor are Europe/Berlin (CEST; CET after 2026-10-25), db, proxy and backup are WIB, Playwright is UTC.
4. Actions table: step, exact command form, result. Write "not recorded" for anything you didn't see. Never invent.
5. Verification table: the checks run, the codes, and the watch passes.
6. **Incidents.** Any secret printed (name the variable, never the value), any prod data written by a test (exact IDs, or "IDs not captured"), any outage. Each one gets a follow-up.
7. State after (SHA, migrations count, process state), then open follow-ups as checkboxes.

## Also update

- The dir's `README.md` sessions-table row, plus any footprint or status lines the session changed.
- `docs/fleet/registry.md` if a port, Redis db, DB, cert or static root was allocated or changed (update the row and the stamp).
- `docs/fleet/profiles/<app>.md` if a gotcha, the deploy form or the footprint changed (bump the profile version).

## Commit (only when the user says so)

Stage only this session's files. Other untracked dirs or another session's files stay out. Message: `docs(<slug>): session-NNN — <topic> (YYYY-MM-DD)` plus the attribution trailers. Before committing, check that `git diff --cached` contains no DB URL with a password and no token.
