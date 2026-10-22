# eventopia — profile

**Profile version:** 5 (S073 redeploy to `89344cdb`) · **Stamped:** 2026-10-23 · **Sources:** eventopia-app-reports up to session-073 (2026-10-23), registry 2026-10-19, repo docs at `89344cdb` (`origin/main` = prod, fetched 2026-10-23)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| What | Where (`~/Projects/eventopia/…`) |
|---|---|
| Per-release deploy order, env, post-checks | `docs/launch/<feature>-deploy.md` (110 notes; latest `ux-revamp-deploy.md`). Every release's note wins over this profile |
| Migrations | `packages/db/MIGRATIONS.md`, migrator `packages/db/run-migrate.mjs` |
| Key rotation (Ed25519, PII keys, `VITE_TICKET_PUBLIC_KEY` encoding) | `docs/engineering/key-rotation.md` |
| Observability (GlitchTip, OO, OpenPanel, GA4 two-property split) | `docs/engineering/observability.md` |
| Known issues, gateways | `docs/engineering/known-issues.md`, `xendit-gateway.md`, `doku-gateway.md`, `midtrans-gateway.md`, `google-login.md`, `claude-oauth-guide.md` |
| Apex nginx carve-outs (canonical) | `infra/nginx/eventopia-apex-capability-paths.conf` (adapt, see G14) |
| Not what prod runs | `infra/DEPLOY.md` (Docker-only), `infra/DR.md` (stale, S021) |
| Workspace reports | [session-073](../../../eventopia-app-reports/session-073-2026-10-23.md), [session-072](../../../eventopia-app-reports/session-072-2026-10-21.md), [session-070](../../../eventopia-app-reports/session-070-2026-10-18.md), [069](../../../eventopia-app-reports/session-069-2026-10-13.md), [068](../../../eventopia-app-reports/session-068-2026-08-22.md) |
| Memory | `feedback_eventopia_deploy_checklist`, `reference_eventopia_payment_smoke_test`, `feedback_never_delete_real_data`, `feedback_psql_on_app_never_echo_db_url`, `feedback_boot_gates_beyond_env_schema` |

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| api (Bun) | app | PM2 `eventopia-api`, cwd `~/eventopia` | **`*:38001`** (all ifaces, UFW only) | api.eventopia.my | cert `eventopia.my` |
| workers (Bun, BullMQ) | app | PM2 `eventopia-workers`, cwd `~/eventopia` | metrics **`*:9091`** | — | — |
| web-public (Next standalone) | app | `eventopia-web-public`, `apps/web-public/.next/standalone/apps/web-public` | 10.0.0.5:38100 | eventopia.my apex, `*.eventopia.my` (tenants), eventopia.co.id + www (marketing), custom domains | `eventopia.my` / `eventopia.co.id` |
| console (Next) | app | `eventopia-console` | 10.0.0.5:38200 | app.eventopia.my | `eventopia.my` |
| operator (Next, `apps/admin`) | app | `eventopia-operator` | 10.0.0.5:38400 | admin.eventopia.co.id | `eventopia.co.id` |
| checkin PWA (Vite static) | proxy | `/var/www/eventopia-checkin` | — | checkin.eventopia.my | `eventopia.my` |
| nginx | proxy | `eventopia.conf`, `eventopia-coid.conf`, `eventopia-custom-domains.conf` (real files in `sites-enabled/`) | — | `www.eventopia.my` → 301 eventopia.co.id | — |

- PM2 under `devops`, ecosystem `~/eventopia/ecosystem.config.cjs` (**untracked in git**); one shared root `.env`, each app's `.env` a symlink to it. Max mem 500M (api/workers), 700M (Next).
- Certs: `eventopia.my` (apex + `*`) exp 2027-01-08; `eventopia.co.id` (apex, admin, www) exp 2026-12-07. Both dns-cloudflare (`cloudflare-eventopia.ini`), reloaded by the proxy deploy hook (since 2026-10-19, proxy S008).
- CF: `eventopia.my` zone is **Full, not strict** (S024, for custom domains). Restart baseline 10-23 (after S073): api ↺2, workers ↺2, web-public ↺3, console ↺2, operator ↺1. web-public and operator still run the `b35dfb70` build (S073 changed nothing functional there).

## Data
| Store | Facts |
|---|---|
| Postgres `eventopia` on db | owner role `eventopia` (non-superuser, **BYPASSRLS**, member of `app_tenant`, owns `public`); 73 MB, ~20 conns; **171 migrations** (0000–0170) in `drizzle.__drizzle_migrations` |
| Redis db **6** on db | 6,508 keys, 36 clients. **Redis-only state:** `org:meta:*`, `org:slug:*`, `org:name:*`, `membership:*` (org identity), `sess`, `wa`; BullMQ `bull:wa-send`, `bull:payments`, `bull:ticket-delivery`, … RDB only, no AOF |
| Object storage | DigitalOcean Spaces bucket `eventopia` (`sgp1`); public cover reads still broken (README) |
| Email | Resend (`EMAIL_PROVIDER=resend`, `eventopia.my` verified) |
| Backups | backup host daily `pg/eventopia`; pre-deploy `pg_dump -Fc` → `db:/root/eventopia-backups/`; `.env` copies + Redis org export → `app:~/eventopia-backups/` |

## Deploy
- **Mode:** PM2 pull-on-host from `main`, pinned SHA (`git fetch`, check `origin/main` = analysed SHA, `git merge --ff-only`), `pnpm install --frozen-lockfile`.
- **Pre-flight:** memory checklist: read every new migration's SQL, backfills (dry run), new env vars (`.env.example` diff + `process.env` grep), full `git log`, the `docs/launch/` note, boot-path diff for new fail-closed gates. Export `org:*` from Redis db 6 before touching identity code (S069).
- **Order (default; the launch note overrides):** migrate (`packages/db/run-migrate.mjs`, verify the count in the DB) → api + workers **together** → backfills → web-public → console → operator → checkin.
- **Restart:** `pm2 startOrRestart ecosystem.config.cjs --only eventopia-api,eventopia-workers` from `~/eventopia`. Never `pm2 restart --update-env` to pick up `.env` (G1).
- **Builds:** one app at a time, `NODE_OPTIONS=--max-old-space-size=4096`; watch swap (~1.8/4 GB is normal). `NEXT_PUBLIC_*` / `VITE_*` are build-time.
- **Runtime:** api/workers = Bun (symlinked into `/usr/local/bin`, S062); Next standalone = PM2 `node` = system v24.18.0.
- **Check-in PWA:** build on app → deploy app → proxy directly (skill `static-deploy-to-proxy`; Mac relay is the fallback, one binary stream per ssh call, `tar tzf`, stage in `/tmp`, assert `index.html` + `sw.js`, backup `/var/www/eventopia-checkin.bak-<ts>`, `rsync -a --delete`).
- **Rollback (S070):** `git checkout <prev>` on app, rebuild web-public/console/admin, restore the check-in backup dir, `pm2 startOrRestart`. Migrations are additive; DB fallback = the pre-deploy dump. Never restore `.env` from a pre-deploy copy (S070: stale DB password).

## Verify (after deploy)
| Check | Expect |
|---|---|
| `curl http://10.0.0.5:38001/healthz` / `/readyz` (or `https://api.eventopia.my/…`) | 200; readyz db + redis true. Wait ≥20 s after restart (S069) |
| eventopia.my, a tenant hub, app.eventopia.my/login, checkin.eventopia.my (+ `sw.js`, manifest), admin.eventopia.co.id/login | 200 |
| `/v1/public/directory/{events,organizers,facets}` | 200 |
| www.eventopia.my | 301 → eventopia.co.id (by design) |
| Logs | `~/.pm2/logs/eventopia-{api,workers,web-public,console,operator}-{out,error}.log` (CEST). No FATAL / `[pii]` lines; workers list 34 queue processors (incl. `payout-in-doubt-alert`) |
| Errors | GlitchTip org `eventopia`: 17 `eventopia-backend`, 18 `eventopia-web`, 19 `eventopia-checkin` |
| Analytics | OpenPanel `eventopia-console` / `-operator` / `-checkin`; GA4 product `GT-KF6WDXJF`, marketing `G-8YBGDDMSQ3` |
| Kuma | **no monitor exists** for eventopia prod |

## Known noise
- OpenTelemetry "duplicate registration" lines at api/workers start (S069, S070).
- api.eventopia.my 502 for ~10 s right after an api restart (S069); operator `/login` curl `000` on first hit (~11 s cold start, S070).
- `operator.eventopia.my` 404s: retired in S013 (S070).
- Old hashed check-in chunk still 200 after `rsync --delete`: Cloudflare edge cache (S067).
- `email_message` rows `FAILED`/`RESEND_422` for `@example.com` test addresses (S068, S069).
- Set-PIN limiter 429 on the 3rd fast request, clears in a minute (S069).
- Console e2e: 24 pre-existing failures on `main` (S064); `crew-removal-live`/`gate-scope-live`/`gate-wedge-timing` flaky (S065).

## Smoke test
- **Default (S070):** HTTP-level, read-only: the Verify table. No booking POSTs, no orgs, nothing to clean.
- **Deeper (reversible):** disposable org via email OTP on an `example.com` address, OTP read from Redis db 6; payment intent via the platform Xendit gateway, left unpaid (S072: an organizer with KYC only `SUBMITTED` + MoU v2 signed can still create a QRIS intent, so no operator account or KYC fixture is needed any more). Free ONLINE orders auto-fulfil to PAID (tickets with signed tokens) and exercise `cancel-free` (1-seat order) and seat release. Recipe: memory `reference_eventopia_payment_smoke_test`.
- **Never:** a Gmail/`googlemail` address for a test org (canonicalises to a real inbox); seed prod; a check-in smoke against a live event (burns a real slot, S067: use a past event); DELETE by pattern.
- **Cleanup:** exact captured IDs only, FK order, include the `membership:<subject>` key (S047) and the `account` row (S017), explicit `COMMIT` in the heredoc (S046), verify row-count deltas vs baseline.

## Gotchas
1. `pm2 restart --update-env` does not reload `.env`: the ecosystem file parses it at `require()`. Use `startOrRestart`; check env by name in `/proc/<pid>/environ`, not `pm2 env` (S008, S013, S054).
2. `drizzle-kit migrate` / `pnpm db:migrate` fail silently over SSH and read the dev default URL. Use `run-migrate.mjs` and count rows in the DB (S001, S009, S068).
3. `source .env` breaks on unquoted `<>` in `EMAIL_FROM`. Use `node --env-file` / `bun run --env-file=../../.env` (S009; memory).
4. Bun not on PATH over non-interactive SSH: fixed with `/usr/local/bin` symlinks (S009, S062).
5. Parallel builds OOM (tsc exit 137 at swap 3967/4095 MB). Build one app at a time with a 4 GB heap (S009, S067).
6. api and workers are one unit: restart them together (S066).
7. api runs Bun source in memory: a `contracts` change needs an api restart, not just a web-public rebuild (S023).
8. GlitchTip DSNs need the dash-less 32-hex key; DSNs are baked into all 4 frontends (S009).
9. Admin needs its own `NEXT_PUBLIC_OPENPANEL_CLIENT_ID` at build (shell override); the root `.env` holds console's (S009, S014).
10. `VITE_TICKET_PUBLIC_KEY` is base64url of the raw 32-byte key, not SPKI base64; the check-in PWA white-screened for weeks (S027, S029). Before publishing, verify the built bundle carries the prod key and verifies a real token (S067).
11. **Boot gates (S073):** since `89344cdb`, api and workers (and any process loading `@eventopia/db`/`@eventopia/keys`) also refuse to start under `NODE_ENV=production` without `EVENTOPIA_ED25519_PRIVATE_KEY`/`_PUBLIC_KEY`, `EVENTOPIA_PII_ENC_KEY`, `EVENTOPIA_PII_HMAC_KEY`, and refuse the DEV signing key; a `VITE_APP_ENV=prod` check-in build fails without `VITE_TICKET_PUBLIC_KEY`. Prod verified compliant 2026-10-23. Presigned uploads sign `content-type` (public uploads raster-only, 415 `UPLOAD_TYPE_NOT_ALLOWED`); ship console with api. `ADMIN_TRUSTED_PROXY_HOPS` is optional and only matters with `ADMIN_IP_ALLOWLIST` (prod has neither). `PIN_PEPPER` is a hard boot gate in production (S046). Rotation is lock-out-free: set the new value and move the old one to `PIN_PEPPER_PREVIOUS`; sign-in re-hashes (S071). Only the api loads it. Diff the whole boot path, not just the env schema (memory).
12. `sites-enabled/eventopia.conf` is a real file, not a symlink: edit it there. Never leave a backup inside `sites-enabled/` (duplicate upstream, reload refused) (S057).
13. A bare `return` in an nginx `server{}` beats every `location{}`: wrap it in `location /` (S041).
14. Apex carve-outs from the repo snippet must omit `X-Forwarded-Proto` (self-rewrites `eventopia_web`) (S044).
15. psql printed the prod `DATABASE_URL` when the command was built as a spaced string: use the quoted-var function + redaction sed (S070). `tr -d "\x27"` deletes `x`, `2`, `7` in GNU tr: use sed (S070).
16. `/root` on db is 700: `sudo -u postgres pg_dump -f /root/…` fails. Dump to `/tmp`, then move (S068).
17. Name-index backfill dry run cannot see in-batch duplicates (S069).
18. `NEXT_PUBLIC_*` change = rebuild at the same commit; `PUBLIC_WEB_BASE_URL` must be the bare apex (S054).
19. Open console / check-in tabs keep the old bundle until a hard reload (S068, S069, S070).
20. The shared root `.env` carries console's OpenPanel client id, so an admin build needs `NEXT_PUBLIC_OPENPANEL_CLIENT_ID=822c5a7b-64ef-44c0-b441-87e14f3b0b2c` as a shell override (gotcha 9). S070 built admin without it (live bundle held console's id); S072 used the override (verified: own id in, console's out).
21. Check-in PWA over `devops@app` → `root@10.0.0.2` worked first time (S072). Keep the previous hashed assets in the new dir (`cp -a --update=none` old `assets/.`) when a gate may be open. Never curl the new hashed asset URL before the swap: Cloudflare caches the SPA fallback (HTML) for it. Send multi-line remote logic as `bash -s` on stdin and use `ssh -n` for inner calls; an unescaped `$VAR` in a double-quoted ssh command expands on the Mac (S072 staged to `/root/.staging-*` that way).
22. `operator-audit-verify CHAIN BREAK at seq 56 (row_hash_mismatch)` logs every 10 min (about 144 a day) since 2026-07-10 (S017): pre-existing, not a deploy regression. Diagnosed in the S072 addendum: only that one row (the sole `audit.export`, "QA test") fails, all `prev_hash` links and the other 534 hashes verify. It predates the writer fix `2be3f840` (2026-08-08), which needs no backfill, so it never clears. `verifyChain` stops at the first break, so it cannot see problems after seq 56: to check the whole chain, recompute every row without early exit (read-only, in memory). Decision R15 in `open-decisions.md`.

## Open items
- `~/eventopia/.env` is now mode 600 (S072). `PIN_PEPPER` echoed in S069, **rotated S071** (old value kept as `PIN_PEPPER_PREVIOUS` until the 16 pre-rotation PINs are re-hashed or cleared; never restore an `.env` backup from before S071). Meta tokens exposed S053, unrotated by choice.
- `env-pre-b35dfb70-*` secrets copy **deleted 2026-10-23** (S073; `.env` unchanged since 10-19, so it was redundant). `app:~/eventopia-backups/` now holds only build logs, the 10-13 Redis org export and the proxy-ts stash patch. Registry counts 20 eventopia `.env*bak*` files on app (not re-counted).
- Prod Xendit key not exercised for the bank-code map; one payout profile stores `PLACEHOLDER` (S070).
- `ANTHROPIC_AUTH_TOKEN` (OAuth) has no refresh loop; died once unnoticed (S024, S053).
- Operator console: no MFA (`OPERATOR_MFA_ENABLED=false`), no IP allowlist (S052, S053).
- WA templates: `pin_security_notice_id` rejected (S056), `attendee_offer` not submitted (S063).
- **Registry (10-19):** api `*:38001` and workers `*:9091` listen on all interfaces; only UFW protects them.
- **Registry:** `eventopia-custom-domains.conf` `~^.+$` catches every unknown :443 name, including `<tenant>.seenow.ac`.
- **Registry vs S057:** S057 reconciled `eventopia.conf` enabled/available; on 10-19 they differ again (enabled 08-21, available 08-17). The enabled file is authoritative.
- **Registry vs S069:** registry §1 says app cannot SSH to proxy; S069 reached `root@10.0.0.2` from `root@app` by key, while grobiz S062 showed `devops@app` is refused. **Resolved 2026-10-20:** `devops@app` now reaches `root@proxy` ([app s006](../../app-sysadmin-reports/session-006-2026-10-20.md)); direct static deploy is the default, Mac relay the fallback.
- Certs: `eventopia.co.id` expires 2026-12-07, `eventopia.my` (+ wildcard) 2027-01-08. Renewals reload nginx through proxy's global certbot deploy hook (since 2026-10-19), so no manual reload. Check the served serial after the first renewal (the earlier "~11-07, no hook" note was wrong).
- Proxy check-in rollback dirs: none left. `eventopia-checkin.prev-20261021-105200` deleted 2026-10-23 (S073; its 4 assets were all inside the live dir first). The next check-in deploy creates a fresh `.prev`.
- No Kuma monitor for eventopia prod (monitor survey).
- Dev (`*.dev.eventopia.my`) is stopped and ~920+ commits behind prod (S056; registry §3).
- `docs/launch/ux-revamp-deploy.md` can be archived now that its release has shipped (S072). `OPS_ADMIN_TOKEN` and the `/internal/.../kyc/verify` route are gone (KYC is approved only in the operator console, which needs opened documents).
- Unverified: whether the deprecated `NEXT_PUBLIC_GA_MEASUREMENT_ID` was blanked (S054).

## Verify live
```bash
APP='ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app'
$APP 'pm2 ls | grep -E "eventopia"'
$APP 'ss -tlnH | grep -E ":(38001|38100|38200|38400|9091) "; git -C ~/eventopia log -1 --format="%h %cd" --date=short'
$APP 'curl -s -o /dev/null -w "%{http_code}\n" http://10.0.0.5:38001/readyz; stat -c "%a %n" ~/eventopia/.env'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db 'redis-cli -n 6 DBSIZE; redis-cli -n 6 --scan --pattern "org:meta:*" | wc -l'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d eventopia -c 'select count(*) from drizzle.__drizzle_migrations'"
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -la /etc/nginx/sites-enabled | grep eventopia; certbot certificates 2>/dev/null | grep -A2 "Name: eventopia"'
```
