# grobiz Backup — Design Spec

**Date:** 2026-06-07
**Status:** Design approved — not yet implemented (planning only, nothing touched on any server)
**Scope:** Add full backup coverage for the grobiz product family across `db`, `erp`, and `app`, landing on the `backup` server. App-scoped work (touches 4 servers) — when executed it becomes a `grobiz-app-reports/` session.

---

## 1. Problem

grobiz (`gro.biz.id`, multi-tenant UMKM SaaS — see [[grobiz-app]]) went to production on 2026-06-05, **after** the `/opt/backup` framework was last touched (2026-05-25). As a result, almost none of grobiz's stateful data is backed up today.

### Live audit findings (2026-06-07, read-only)

| Component | Location | Size | Backed up today? |
|---|---|---|---|
| Postgres `grobiz` (app DB: tenants, plans, flags, billing, registry) | db `10.0.0.1` | 9.7 MB | ❌ **No** — not in any tier |
| Tenant ERPNext site `59aba5d4.gro.biz.id` (real customer) + its MariaDB `_<hash>` DB | erp `10.0.0.6` + db MariaDB | 732 KB + DB | ❌ **No** |
| 3 pool sites (`pool-9c72fb93`, `pool-cde6a7e2`, `pool-dc1177aa`) | erp | ~730 KB ea | ❌ No — **intentionally excluded** (pre-warmed, empty, reconstructible by the pool warmer) |
| Base site `erp.gro.biz.id` | erp + db MariaDB | 3.9 MB | ✅ Yes — `erp-bench.sh` (tier-2, 7d) + local cron 02:30 |
| App `.env` (secrets, **not in git**) | app `10.0.0.5` | 2.4 KB | ❌ **No** |
| Redis `db4` (grobiz) | db `10.0.0.1` | 1 key | ❌ No — **intentionally excluded** (verified: holds only `admin:session:*`; AOF off; session-only, rebuildable) |

**Key facts shaping the design:**
- A mature pull-based framework already exists on the **backup server** (`/opt/backup/`): daily 01:00 WIB run via `backup.sh`, `notify.sh` Telegram alerts, `rotate.sh` tiered retention, weekly `verify.sh`, and Fluent Bit → OpenObserve `backup` stream (job names auto-extracted from `[prefix]` log lines). **We extend it; we do not build anything parallel.**
- Whole grobiz dataset is **~12 MB today** — storage/cost is a non-issue. The real challenges are **(a) catching every tenant site dynamically** as signups create them, and **(b) consistency** between the Postgres tenant registry and the matching ERPNext sites.
- App server holds **no local user data** — only `.env` is irreplaceable there (code is in GitHub).

---

## 2. Decisions (locked with user)

| # | Decision | Choice |
|---|---|---|
| 1 | Offsite tier | **Backup server only** (extend `/opt/backup`). No S3/B2/restic offsite this round. *(Note: off-box copy remains an open fleet-wide follow-up — see §8.)* |
| 2 | Frequency / RPO | **Every 6h** (00:00 / 06:00 / 12:00 / 18:00 **WIB** — backup server is `Asia/Jakarta`). Up to 6h loss. grobiz-only cadence; rest of fleet stays daily. |
| 3 | Redis db4 | **Skip** — verified session-only, non-durable. |
| 4 | Retention (customer data) | **GFS, actively pruned on the backup server: 4 intraday (last 24h @ 6h) + 7 daily + 4 weekly.** Obsolete *backup files* are deleted. |
| 7 | Live-system safety | **Never delete/drop anything on app, db, or erp.** All source ops read-only (`pg_dump`, `bench backup`, forced-`cat` of `.env`); verification non-destructive (no temp-DB/DROP on db); rsync **without** `--delete`. Deletion happens *only* on the backup server's own snapshot store. |
| 5 | Tenant ERPNext capture method | **Approach A — Frappe-native `bench backup` per site** (chosen over direct mysqldump or LVM snapshots). |
| 6 | App `.env` | Back up via a **new backup→app pull SSH path** (approved). |

### Why Approach A for tenant capture
`bench --site <site> backup --with-files` produces a coherent set (MariaDB DB + public files + private files + `site_config.json`) and restores cleanly via `bench restore` — the same proven pattern `erp-bench.sh` already uses for the base site. The rejected alternatives:
- **B (direct mysqldump of `_<hash>` DBs + tar files):** forces a fragile `_<hash>`→site-name mapping, manual multi-step restore, risks DB/files inconsistency, loses Frappe tooling.
- **C (LVM/filesystem snapshot):** overkill for ~12 MB; snapshot infra not present; not how the fleet operates.

---

## 3. Architecture

All additions live under `/opt/backup/` on the **backup server** (`10.0.0.4`). grobiz runs on its **own 6h cron** via a new `backup-grobiz.sh` wrapper (so the rest of the fleet stays on the single daily `backup.sh`); the 01:00 WIB grobiz run coincides with the fleet daily. Three new job scripts, one new config tier, extensions to `rotate.sh` and `verify.sh`. Pull model throughout — backup reaches into the cluster; prod hosts never push.

```
/opt/backup/
├── backup.sh              # unchanged — fleet daily run (01:00 WIB)
├── backup-grobiz.sh       # NEW — grobiz-only wrapper, runs the 3 jobs + rotate; cron every 6h
├── config.sh              # MODIFIED — add grobiz paths + retention vars (mode 600)
├── rotate.sh              # MODIFIED — add grobiz GFS tier (intraday/daily/weekly)
├── verify.sh              # MODIFIED — add grobiz pg + sites checks
├── notify.sh              # unchanged (reused for Telegram alerts)
└── jobs/
    ├── grobiz-pg.sh       # NEW — pg_dump grobiz from db
    ├── grobiz-sites.sh    # NEW — bench backup per tenant site on erp + rsync
    └── grobiz-appconfig.sh# NEW — pull app .env
```

### Data flow
```
00:00 / 06:00 / 12:00 / 18:00 WIB   backup-grobiz.sh   (cron: 0 0,6,12,18 * * *)
  ├─ [grobiz-pg]        backup ──pg_dump──▶ db(10.0.0.1)  ──▶ /root/backups/pg/grobiz/
  ├─ [grobiz-sites]     backup ──ssh──▶ erp(10.0.0.6): bench backup --with-files (per tenant site)
  │                     backup ──rsync◀── erp sites/*/private/backups/  ──▶ /root/backups/bench/grobiz/<site>/
  ├─ [grobiz-appconfig] backup ──ssh/scp──▶ app(10.0.0.5):/home/devops/grobiz/.env ──▶ /root/backups/appconfig/grobiz/
  └─ rotate.sh (grobiz tier only)
```

Ordering: **`grobiz-pg` runs first** (snapshot the tenant registry), then `grobiz-sites` (the data those rows point at), then `grobiz-appconfig`. The whole run takes seconds at current scale, so registry + sites form a near-consistent snapshot each run. The 01:00 run lands at the quietest hour (minimizes in-flight signups mid-run); the 07:00/13:00/19:00 runs add intraday RPO coverage.

---

## 4. Job specifications

### 4.1 `jobs/grobiz-pg.sh` — Postgres `grobiz`
- Reuses existing PG connection vars from `config.sh` (`PG_HOST=10.0.0.1`, existing superuser creds — see §8 least-priv follow-up).
- `pg_dump --format=c --blobs --no-owner grobiz` → `/root/backups/pg/grobiz/grobiz-YYYY-MM-DD-HHMM.dump` (time component so intraday runs don't overwrite).
- Log `[grobiz-pg] Starting dump…` / `[grobiz-pg] Done` (so OpenObserve extracts `job=grobiz-pg`).
- Non-zero exit or empty dump → `notify.sh` Telegram alert.
- Mirrors the existing `tier2-pg.sh` structure exactly.

### 4.2 `jobs/grobiz-sites.sh` — tenant ERPNext sites
- SSH to erp (`10.0.0.6`) using the **existing** dedicated key `/root/.ssh/id_ed25519_pull`.
- **Dynamic enumeration:** list `sites/*.gro.biz.id`, then exclude `erp.gro.biz.id` (already covered by `erp-bench.sh`) and `pool-*.gro.biz.id` (pre-warmed/empty). Everything remaining is a real tenant — future signups are auto-included with zero config.
- For each tenant site: `sudo -u frappe bench --site <site> backup --with-files` (via the existing `/usr/local/sbin/bench` shim that `cd`s into the bench dir for non-interactive SSH).
- `rsync -a` (**no `--delete`** — intraday snapshots accumulate on the backup server; `rotate.sh` prunes them via the GFS rule) each site's `private/backups/` → `/root/backups/bench/grobiz/<site>/`. `bench backup` already names archives with a timestamp prefix, so 6h runs produce distinct sets. Set a small `backup_limit` on erp so its *local* copies don't pile up between rsyncs.
- Per-site verify inline: confirm a non-empty `*-database.sql.gz` arrived.
- Log `[grobiz-sites] <site> done` per site, `[grobiz-sites] All N tenant sites backed up`. Any site failure → Telegram alert (but continue the others; report which failed).
- **If zero tenant sites exist:** log `[grobiz-sites] No tenant sites (only base + pool) — nothing to do` and exit 0 (not a failure).

### 4.3 `jobs/grobiz-appconfig.sh` — app `.env`
- SSH/scp to app (`10.0.0.5`) — **requires the new pull key, see §5**.
- Copy `/home/devops/grobiz/.env` → `/root/backups/appconfig/grobiz/.env-YYYY-MM-DD-HHMM`, **chmod 600** immediately (it contains secrets; consistent with `config.sh` already holding plaintext secrets at 600).
- Log `[grobiz-appconfig] Done`. Missing/empty file → Telegram alert.
- *(Only the live `.env` is pulled — the `.env.bak.*` history on app is left in place, not archived.)*

---

## 5. New access to provision (the one new wiring)

backup→db and backup→erp keys already exist and work. backup→**app** does **not**. To enable `grobiz-appconfig.sh`:
- Generate (or reuse `id_ed25519_pull`) a key on backup; add its public key to app for a user that can read `/home/devops/grobiz/.env` (i.e. `devops@app`, or `root@app` then `sudo`/path-read).
- Restrict if practical (e.g. `from=10.0.0.4` and/or a forced-command wrapper that only emits the `.env`), matching the cluster's internal-only posture.
- Verify the path works read-only before relying on the cron.

Everything else (PG creds, erp pull key, bench shim, Telegram, Fluent Bit job extraction) is **already in place** and reused.

---

## 6. Retention — GFS: intraday + daily + weekly

New `grobiz` tier in `config.sh` + `rotate.sh`. Applies to `/root/backups/pg/grobiz/`, `/root/backups/bench/grobiz/<site>/`, and `/root/backups/appconfig/grobiz/`. Pruning keys off the `YYYY-MM-DD-HHMM` in each filename (not mtime, which rsync/restore can perturb).

Retention is driven by each file's **mtime** (an absolute instant, preserved by `rsync -a`, rendered in WIB on the backup server — robust across my pg/appconfig filenames and Frappe's CEST-stamped bench filenames). The **00:00 WIB** run is the daily/weekly anchor.

**A snapshot is RETAINED if any of:**
1. **Intraday:** age ≤ 24h (retains all 4 runs @ 6h → RPO 6h for the last day).
2. **Daily:** it's the **00:00 WIB** run (mtime hour `00`) AND age ≤ 7 days (7 rolling dailies).
3. **Weekly:** it's the **00:00 WIB Sunday** run AND age ≤ 30 days (4 weekly snapshots).

Anything not retained is **deleted** (this is on the backup server only — the explicitly-authorized cleanup). Steady state per backed-up object: ~4 intraday + 6 older dailies + 4 weeklies ≈ 14 snapshots. At ~12 MB total today this is negligible.

- The 06:00/12:00/18:00 runs are intraday-only (deleted once >24h old); the 00:00 run is the daily/weekly anchor.
- A tenant-site "snapshot" is the 4 Frappe files sharing one timestamp prefix; they share an mtime so they're kept/deleted together.
- `rotate.sh` grobiz tier runs `rm` **only** under `$BACKUP_ROOT/{pg,bench,appconfig}/grobiz/`. It never connects to app/db/erp. `backup-grobiz.sh` calls it (grobiz-only mode) at the end of each 6h run.

Existing tiers (tier1 4d, tier2 7d, tier3 3d) are untouched. Base `erp.gro.biz.id` stays on its current tier-2 7d under `erp-bench.sh`.

---

## 7. Verification (extends weekly `verify.sh`, Tue 21:00 UTC) — **non-destructive only**

Per the no-delete/no-drop constraint, verification never restores into or drops anything on production:
- **grobiz Postgres:** `pg_restore --list` of the latest dump (parses the archive's table-of-contents, confirms it's a valid restorable custom-format dump + non-empty object count). **No temp DB created, no restore, no DROP.**
- **grobiz sites:** for each site's latest backup, `gzip -t` the `*-database.sql.gz` for integrity + assert non-empty. (Same bar as the existing erp-bench verify; no throwaway Frappe sites.)
- **app `.env`:** assert latest copy exists and is non-empty.
- Any failure → `notify.sh` Telegram alert, same as the rest.

---

## 8. Restore runbook (documented, not executed)

- **Postgres `grobiz`:** `pg_restore --no-owner -d grobiz /root/backups/pg/grobiz/grobiz-<date>.dump` (drop/recreate DB first for a clean restore; reconnect grobiz API after).
- **Tenant site:** copy the site's backup set to erp, then `bench --site <site> restore <db.sql.gz> --with-public-files <pub.tar> --with-private-files <priv.tar>` (or `bench new-site <site> --restore` if the site shell is gone). Ensure the MariaDB tenant DB host stays `10.0.0.1` and `dns_multitenant` on.
- **`.env`:** copy `/root/backups/appconfig/grobiz/.env-<date>` back to `/home/devops/grobiz/.env` on app, `chmod 600`, `pm2 restart grobiz-api`.
- **Consistency caveat:** restore Postgres and the tenant sites from the **same dated run** so the registry and the sites agree.

---

## 9. Observability

No new wiring needed. The three jobs log to `/var/log/backup.log` with `[grobiz-pg]` / `[grobiz-sites]` / `[grobiz-appconfig]` prefixes; the existing Fluent Bit Lua filter extracts these as `job` values into the OpenObserve `backup` stream (30-day retention). Failures additionally fire Telegram via `notify.sh`.

---

## 10. Out of scope (this round)

- **Offsite / encrypted-at-rest copy.** Chosen backup-server-only for now. ⚠️ grobiz, like the rest of the fleet, still has **no off-box copy** — the existing open follow-up (restic/rclone → S3/B2/Wasabi, encryption at rest, least-priv `backup_reader` PG role) stands and is **not** closed by this work.
- **Redis db4** — verified session-only, non-durable.
- **Pool sites** — reconstructible by the warmer.
- **Base `erp.gro.biz.id`** — already backed up; left on its current `erp-bench.sh` 7d job, untouched.

---

## 11. Implementation checklist (for the execution session)

1. Provision backup→app pull key (§5); verify read-only access to `.env`.
2. Write `jobs/grobiz-pg.sh`, `jobs/grobiz-sites.sh`, `jobs/grobiz-appconfig.sh` (mode 700).
3. Add grobiz paths + retention vars to `config.sh` (mode 600).
4. Write `backup-grobiz.sh` wrapper (mode 700): runs the 3 jobs (pg → sites → appconfig) then `rotate.sh` grobiz tier.
5. Add grobiz cron entry **every 6h** (`0 0,6,12,18 * * *`, WIB) → `backup-grobiz.sh`. (erp `backup_limit` default is 3 — self-limiting, no erp change needed.)
6. Extend `rotate.sh` with the GFS grobiz tier (intraday/daily/weekly per §6) — actively prunes backup-server snapshots only.
7. Extend `verify.sh` with grobiz pg + sites + .env checks.
8. **Dry run** each job manually; confirm dumps land with `YYYY-MM-DD-HHMM` names, sizes sane, Telegram quiet on success.
9. Confirm the next scheduled 6h run succeeds end-to-end; check OpenObserve `backup` stream shows the new `job` values; after 24h confirm intraday pruning leaves the 01:00 anchor.
10. Write the `grobiz-app-reports/` session report + update its README index.

---

*Spec location note: written under `docs/superpowers/specs/` as a pre-implementation design. This workspace is not a git repo, so no commit step. On execution, the work is documented as a `grobiz-app-reports/` session per workspace conventions.*
