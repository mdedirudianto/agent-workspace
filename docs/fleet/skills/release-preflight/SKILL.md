---
name: release-preflight
description: Use when the user asks to deploy, redeploy, release or update an app on the biji production fleet ("deploy latest main of X", "update radho", "ship it"), before any write step - including when they say they already reviewed it.
---

# Release pre-flight

**Core principle:** find out what will actually change on the server, then present a numbered plan in which each write step is its own approval unit. Execution is `pm2-app-deploy` (PM2 apps) or `static-deploy-to-proxy` (static).

## 1. Resolve the target. Never assume one

- Read `/Users/dedi/Operations/docs/fleet/profiles/<app>.md` and the repo runbook it links.
- Run `git fetch` locally. Then compare `origin/main` with the **live** SHA on the server (`ssh … 'cd <dir> && git rev-parse HEAD && git status --porcelain'`). Don't compare against the last report: reports go stale.
- If there are 0 commits, the answer is "already on main" and you stop there.
- Deploy only from `main`. If the work is on a branch, merging it is the user's decision, not a deploy step.
- For multi-instance apps (hoteru: central, tpm, bwalk, radho), list which instances will be behind after this deploy.

## 2. Checklist (one line each, with evidence)

| Check | How |
|---|---|
| Commits / apps touched | `git log --oneline LIVE..SHA`, `git diff --dirstat=files` |
| Migrations | List the new files and **read the SQL**: additive or not, locks on big tables, journal order |
| Backfills / one-off scripts | `docs/launch/`, release notes, commit messages |
| New env vars | Diff `.env.example` and the env schema. Then grep the **whole boot path** for production guards (`process.exit`, `NODE_ENV === 'production'`, throws). An env schema check alone once caused a 7.5-min outage |
| Build-time vars | `NEXT_PUBLIC_*` / `VITE_*` changes force a rebuild of that app |
| Deps | Lockfile diff → install step |
| Ordering rules | The repo's deploy doc, e.g. api before web, admin with api |
| Live state | Read-only: PM2 status and restarts, `free -m` (builds OOM), live events or traffic window, dump disk space |
| Data at risk | Redis-only state, payments, and anything the smoke test could write |

Read-only SSH needs no approval, so run the live checks yourself. Don't list them for the user to run.

## 3. Output (in this order)

1. **Verdict in one line:** what deploys (SHA, N commits, M migrations), or why nothing does.
2. Checklist table with findings.
3. **Numbered write steps.** For each: the commands, the check after it, and the stop condition.
4. Smoke test. Read-only and reversible only: no prod booking or donation POSTs, no seed.
5. Rollback.
6. Questions for the user.

Then stop and wait. "I already reviewed it, just do it" covers the code review. It does not cover the live state (env, DB, instance drift) or the per-step approvals in CLAUDE.md. Say that in one sentence, then present step 1 for approval.
