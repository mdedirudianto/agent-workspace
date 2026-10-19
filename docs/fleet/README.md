# docs/fleet

Live reference for the biji fleet. The ops skills (`~/.claude/skills/<name>` → symlinks into [`skills/`](skills/)) read these files before acting.

| Path | What | Update when |
|---|---|---|
| [registry.md](registry.md) | Hosts, SSH forms, ports (next free app port), Redis db map (next free db), Postgres DBs, certs and expiry, static roots, runtimes | Any allocation or footprint change. Bump the stamp |
| [hosts/](hosts/) | Dated read-only survey snapshots per host (`<host>-YYYY-MM-DD.md`) | Each fleet survey adds new files. Old ones stay as history |
| [profiles/](profiles/) | One versioned profile per app: footprint, deploy form, verify, known noise, smoke rules, gotchas, open items. Each points to the repo-owned runbook instead of copying it | A deploy changes the footprint or teaches a gotcha. Bump `Profile version` |
| [profiles/servers/](profiles/servers/) | One profile per host: access, services, change procedures, health checks, open follow-ups, drift | A server session changes any of these |
| [open-decisions.md](open-decisions.md) | Findings waiting on the user's decision (security, reliability, hygiene), with recommendations and a Decided log | Whenever a finding is raised or decided |
| [skills/](skills/) | Sources of the user-level ops skills: `ops-session`, `release-preflight`, `pm2-app-deploy`, `post-deploy-watch`, `static-deploy-to-proxy` | Only through the skill-testing loop (RED baseline → edit → GREEN re-test) |

## App profiles

[eventopia](profiles/eventopia.md) · [grobiz](profiles/grobiz.md) · [seenow](profiles/seenow.md) · [hoteru](profiles/hoteru.md) (all instances) · [avilia](profiles/avilia.md) · [rekrutme](profiles/rekrutme.md) · [pahala](profiles/pahala.md) · [ytgrab](profiles/ytgrab.md) · [meetgrab](profiles/meetgrab.md) · [duitkas](profiles/duitkas.md) · [miaw-route](profiles/miaw-route.md) · [sijari](profiles/sijari.md) · [legacy apps](profiles/legacy.md) (wagrab, teamy, washop, foucher/feyfa, quranchat/qute, asiaweek, pasarbesar)

## Server profiles

[proxy](profiles/servers/proxy.md) · [app](profiles/servers/app.md) · [db](profiles/servers/db.md) · [erp](profiles/servers/erp.md) · [monitor](profiles/servers/monitor.md) · [backup](profiles/servers/backup.md) · [dev](profiles/servers/dev.md). numa is not profiled yet: SSH there needs per-session approval.

## Rules

- Live beats documented. When a report and a live read disagree, the live read wins, and the drift is recorded under the profile's Open items.
- No secret values anywhere in this tree. Env var names are fine.
- Profiles link the app repo's runbooks (`~/Projects/<repo>/docs/…`). They don't duplicate them.
