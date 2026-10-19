---
name: pm2-app-deploy
description: Use when executing an approved production deploy of an app that runs under PM2 on the biji fleet (app or dev host), or when asked for the exact commands / runbook to do one - pulling a pinned SHA, running migrations, rebuilding, restarting PM2 processes, or changing an app's .env.
---

# PM2 app deploy (execution)

**Core principle:** the repo runbook and the app profile decide the order. Each write step gets its own approval.

The pre-flight is `release-preflight`. This skill covers running the approved plan.

## Before the first command, read these three things

1. `/Users/dedi/Operations/docs/fleet/profiles/<app>.md` gives the footprint, Node runtime, restart form, migrate order and gotchas. It links the repo runbook: **open it.** For example, rekrutme follows `docs/deploy-runbook.md` §8.1.
2. `/Users/dedi/Operations/docs/fleet/registry.md` gives the SSH forms, ports and Redis db.
3. The app's latest workspace session, for what changed last time.

If there's no profile, say so and read the latest 2 sessions plus the repo's deploy docs before writing any command.

## Approval

CLAUDE.md approval is **per step**. "Just do it" or "pre-flight approved" approves the plan. It does not approve every write. Number the steps and send one approval request per write step: backup, pull, migrate, build, restart, static, `.env` edit. A step that fails or surprises you stops the run. Report and re-ask. Don't improvise a fix in the same step.

| Thought | Reality |
|---|---|
| "They said just do it, so I'll skip the gates" | The gates are the user's standing rule. Batch the explanation, not the approval |
| "Read-only checks need approval too" | No. Run them freely |
| "I know the order: build, then migrate" | The profile decides. pahala must migrate **before** build (sitemap prerender queries the DB) |

## Step skeleton (fill in from the profile)

| # | Step | Must check before the next step |
|---|---|---|
| 0 | Re-check `git ls-remote origin refs/heads/main` = pinned SHA | It moved → stop, back to pre-flight |
| 1 | Backup: `pg_dump -Fc` on db (`/root/<app>-backups/`, 0600), `.env` copy `install -m600` | TOC count with `pg_restore -l` |
| 2 | Pull: `git fetch && git merge --ff-only <SHA>` (never `pull`, never `reset --hard`) | `rev-parse HEAD` = SHA, clean tree |
| 3 | Install: lockfile changed → `--frozen-lockfile` | |
| 4 | Migrate (before or after build, per profile) | Applied-count delta = number of new migrations |
| 5 | Build with the profile's Node (`nvm` 22 vs system 24). `NEXT_PUBLIC_*`/`VITE_*` are baked at build time | grep the built bundle for the new value |
| 6 | Restart (see below) | restarts +1, uptime climbing after 30 s, no FATAL in error log |
| 7 | Hand off to `post-deploy-watch` | |

## Restart form

- If the app has an `ecosystem.config.cjs`, use `pm2 startOrRestart ecosystem.config.cjs --only <name>`. The ecosystem file parses `.env` at `require()` time, so `pm2 restart <name> --update-env` keeps the **stale** env (eventopia S008, S013). PM2 also *merges* env, so a var deleted from `.env` lives on in `dump.pm2` (S016).
- Otherwise use `pm2 restart <name>`. Then `pm2 save`, but only if the process list changed.

## Secrets

- To check a var exists, print names only: `grep -c '^KEY=' .env` or `cut -d= -f1`.
- For psql, put the URL in a quoted var and call it through a function, then pipe the output through the redaction sed (memory `psql-on-app`).
- If a secret is printed anyway, say which one and log it as an incident in the session.

## Rollback

Write it before step 2: the previous SHA, the backup paths, and whether the migration is additive (if so, leave the schema alone). Never restore a `.env` copy taken before a credential rotation.
