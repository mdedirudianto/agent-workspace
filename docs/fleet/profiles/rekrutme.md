# rekrutme — profile

**Profile version:** 2 · **Stamped:** 2026-10-20 · **Sources:** rekrutme-app-reports up to session-004 (2026-10-20), registry 2026-10-20, live checks 2026-10-20; prod and dev both deployed at `6b28451` (`origin/main`, `v1.1.0-34`)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
| Doc | Path (in `~/Projects/rekrutme/`) | Owns |
|---|---|---|
| Deploy runbook v2 | `docs/deploy-runbook.md` | first install D0–D11, §3 env reference, §6 smoke, **§8.1 update**, §8.4 PM2/env rules, §8.5 secret rotation, §8.6 CF ranges, **§8.7 rollback**, §9 support behaviour |
| nginx template | `docs/deploy/nginx-rkrt.me.conf.example` | the vhost (apex serves, `www`/`app` 301, CF real-IP) |
| Release notes | `docs/releases/v1.1.0.md` | what shipped, migrations |
| Build / PM2 | `scripts/build-standalone.sh`, `ecosystem.config.cjs` (tracked, used as is) | |
| Workspace | [S002](../../../rekrutme-app-reports/session-002-2026-10-14.md) (first deploy), [S003](../../../rekrutme-app-reports/session-003-2026-10-14.md) (origin → `rkrt.me`) | |

`~/Projects/rekrutme-repo` is an unrelated 2025 repo (`biji-dev/rekrutme-repo`). Don't use its docs.

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| App (Next 16 standalone `server.js` + pg-boss workers in-process) | app | PM2 `rekrutme` (id 42 live 2026-10-20, **fork ×1**), `/home/devops/rekrutme` @ `6b28451` detached (`v1.1.0-34`, S004) | `10.0.0.5:3160` | `rkrt.me` | LE `rkrt.me` (apex, `www`, `app`), HTTP-01 webroot, expires 2027-01-11, **no auto reload** |
| Redirects | proxy | vhost `rkrt.me.conf` | — | `www.rkrt.me`, `app.rkrt.me`, all :80 → 301 `https://rkrt.me$request_uri` | same cert |
| Staging (S004: upgraded from v0.9.0) | dev | PM2 `rekrutme` (id 57, **fork ×1**) under `deploy`, `/home/deploy/rekrutme` @ `6b28451` on branch `dev`, `pnpm build` + `next start -H 127.0.0.1 -p 7007`, system Node 22.22 (**no nvm on dev**) | `127.0.0.1:7007` | `dev.rkrt.me` | dev nginx; testing banner **on** (`NEXT_PUBLIC_SHOW_TESTING_BANNER=true`) |

- Runtime: nvm Node v22.22.0 (system is v24), `HOSTNAME`/`PORT`/`NODE_ENV`/`TZ=Asia/Jakarta` come from `ecosystem.config.cjs`, `.env` read by Node via `--env-file=.env`; `max_memory_restart 1G`; `merge_logs: true` (registry, S002).
- Cloudflare: orange, Full (strict), "Always Use HTTPS" **off**. Registrar Namecheap, domain expires 2027-02-23.
- Vhost: CF real-IP restore scoped to this vhost + `X-Real-IP` to the app; `client_max_body_size` ≥ 25M (CV uploads).
- Mail: MX → Amazon SES inbound; outbound Resend (`noreply@rkrt.me`); DMARC `p=none`.

## Data
| Store | Detail |
|---|---|
| Postgres | `db` 16.9, DB `rekrutme`, owner role `rekrutme` with **CREATE on the DB** (drizzle makes schema `drizzle`, pg-boss makes `pgboss` at start). 12 drizzle migrations (0000–0011), 13 public tables (S002) |
| Queues | pg-boss in Postgres: `parse-cv`, `screen-candidates`, `send-email` |
| Redis | **none** |
| Object storage | DO Spaces bucket `rekrutme` (sgp1, private; logos public-read; CVs via signed URL). **Bucket has no backup** |
| Process memory only | login/apply/forgot-password rate-limit counters (a restart clears them; a second instance would double them) |
| Backups | `/root/backups/pg/rekrutme/`, 5 nightly dumps (registry). Weekly `verify.sh` last ran 10-13, before rekrutme existed |

`.env` names (15, registry): `AUTH_SECRET DATABASE_URL AUTH_URL NEXT_PUBLIC_APP_URL NEXT_PUBLIC_SHOW_TESTING_BANNER TRUSTED_IP_HEADER SPACES_ENDPOINT SPACES_REGION SPACES_BUCKET SPACES_KEY SPACES_SECRET RESEND_FROM_EMAIL RESEND_API_KEY ANTHROPIC_AUTH_TOKEN SENTRY_ENVIRONMENT`. No `SENTRY_DSN`. A stray `.env.test` also sits in the prod checkout (registry).

## Deploy
- **Mode:** PM2 pull-on-host, tag/SHA checkout, standalone build on `app`. Procedure: runbook **§8.1**. Read release notes, list migrations with `git diff --stat <old> <new> -- drizzle/`.
- **Node:** `export PATH="$HOME/.nvm/versions/node/v22.22.0/bin:$PATH"` before any `pnpm`/`pm2` command.
- **Order:** build (`nice -n 10 scripts/build-standalone.sh --production`) → `pnpm db:migrate` (only if `drizzle/` changed, **before** the restart) → `pm2 restart rekrutme` → health. Fresh `pg_dump -Fc` before a release with migrations (§8.1).
- **Build-time vars:** `NEXT_PUBLIC_APP_URL` (`https://rkrt.me`, refused if http/localhost), `NEXT_PUBLIC_SHOW_TESTING_BANNER` (`false`; `true` refuses to build). Changing them = rebuild.
- **Restart forms (§8.4):** `.env` edit → `pm2 restart rekrutme`. Ecosystem edit → `pm2 startOrRestart ecosystem.config.cjs --update-env` (or delete + start), then `pm2 save`. Always restart after a deploy (workers/templates load once).
- **Rollback (§8.7):** code-only = previous tag + rebuild + restart. No down migrations; a restore loses data since the dump, not rehearsed. S003 kept a 1-minute origin rollback (vhost copy + standalone + `.env` backups); stale now.

## Verify (after deploy)
| Check | Expected |
|---|---|
| `https://rkrt.me/api/health` | 200 `{"status":"ok","db":"ok","workers":"ok","version":"1.1.0"}` + HSTS `max-age=63072000; includeSubDomains; preload`. 503 `workers:"not_started"` = DB was down at boot, restart |
| `/`, `/login`, `/signup`, `/privacy`, `/robots.txt`, `/forgot-password` | 200, no "Testing" stripe, no demo box |
| `https://app.rkrt.me/x?y=1`, `https://www.rkrt.me/`, `http://rkrt.me/login` | 301 to `https://rkrt.me` with path+query kept |
| PM2 log at start | `[worker] All job handlers registered`, `[instrumentation] pg-boss workers started`, no `[env] error` |
| Logs | `~/.pm2/logs/rekrutme-out.log` / `-error.log` → OpenObserve stream `app`, `app_name = 'rekrutme'` |
| GlitchTip / Kuma / OpenPanel | **none yet** (no `SENTRY_DSN`; registry lists no Kuma monitor for rkrt.me, only `dev.rkrt.me` #41) |

## Known noise
- Exactly one `[env] warning: ANTHROPIC_AUTH_TOKEN is set …` per start (S002).
- `Server Reference ID did not match …` from scanners POSTing fake Server Action headers to `/` (S002).
- `nginx -t` warning `protocol options redefined for 0.0.0.0:443 in vaultwarden.conf:15`, pre-existing (S002).
- PM2 log/file times are CEST (WIB − 5 h); app renders WIB (S002).
- 429 after 5 rapid requests from one IP on limited routes, by design (S002).

## Smoke test
- Runbook **§6** (13 checks). Use throw-away `delivered+…@resend.dev` addresses, a throw-away company, then **delete the company in Settings** and confirm 0 rows / 0 queue rows / 0 bucket objects (S002, S003).
- Afterwards `pm2 restart rekrutme` to clear limiter counters before the owner signs in (S002).
- Real-IP proof: hit the prefill route from two networks; the limiter must key on the visitor (S002 #11).
- **Do not:** run the seed (wipes every row), use the repo `Dockerfile`/compose on the cluster, treat `tests/e2e` as a prod gate (it deletes its own local data) (README, runbook §10 #13).

## Gotchas
1. Without `merge_logs: true` PM2 names logs `rekrutme-out-<id>.log` and fluent-bit's `*-out.log` glob misses them (S002).
2. `NEXT_PUBLIC_APP_URL` is baked: moving the origin needed a full rebuild, not just `.env` (S003).
3. Exactly one fork instance: in-memory limiters + in-process workers (README, S001).
4. Real-IP restore is per vhost; app needs `TRUSTED_IP_HEADER=x-real-ip`, else limiters key on Cloudflare (S002).
5. Apex HSTS has `includeSubDomains`: every `*.rkrt.me` must answer HTTPS; don't submit to the preload list without the owner (S003).
6. HTTP-01 webroot cert: new subdomain = re-issue; "Always Use HTTPS" must stay off; nginx reload after renewal is handled by the proxy deploy hook since 2026-10-19 (S002, proxy S008).
7. `pgrep -f build-standalone` matches the SSH command itself; use `ps … | grep "[b]uild-standalone"` (S003).
8. macOS `sed` has no `\s`: a first vhost edit silently left lines commented (S002).
9. Workstation has no `github.com` host key: check tags from `app` (S002).
10. Ecosystem `env` block beats `.env`, and PM2 caches it plus the first shell's env (runbook §8.4, S002 restart via delete+start).
11. Build replaces `.next` while the old process serves: keep build → restart short; after `0009_company_slugs`, old code can't create companies (runbook §8.1).
12. `ANTHROPIC_AUTH_TOKEN` wins over `ANTHROPIC_API_KEY` while present: remove the token line when swapping (runbook §8.5).
13. Runbook/S001 text "rkrt names hit the Eventopia 404" is outdated: unknown names get the default :80 page or the eventopia catch-all on :443 (S002; registry §7).

## Open items
- Owner: GlitchTip project + `SENTRY_DSN` (D8a), Kuma keyword monitor on `https://rkrt.me/api/health` (D8b). Registry confirms neither exists.
- Owner: own sign-up at `https://rkrt.me/signup` (D10), not confirmed in any report.
- Owner: secrets into Vaultwarden (`AUTH_SECRET`, DB password exist only in `~/rekrutme/.env`); rotate `ANTHROPIC_AUTH_TOKEN` (pasted into a chat 10-14) for a workspace-scoped key + spend limit; rotate the Resend key; enable `rkrt.me` auto-renew.
- D11: dumps exist (registry). First `verify.sh` covering rekrutme is Tue 2026-10-20 21:00; no restore test yet.
- ~~Fleet: certbot deploy hook on `proxy`~~: done 2026-10-19 (proxy S008).
- Dev (S004): its Postgres is the local cluster on `dev` (DB `rekrutme`, role `postgres`); schema was reset and re-migrated 0000–0011 on 2026-10-20. It runs on the owner's subscription token copied from the local project `.env` (owner-approved). Pre-upgrade copies on dev: `~/rekrutme-pre-6b28451/`, `~/dumps/rekrutme-dev-pre-6b28451.dump`; prod dump `root@db:/root/rekrutme-backups/rekrutme-pre-6b28451-*.dump`. Delete them once accepted.
- Dev: CSP, retention purge of soft-deleted rows, graceful pg-boss stop, pg-boss retry when DB was down at boot, candidate data export (runbook §10).
- Remove S003 rollback copies on `app`: `~/rekrutme-standalone-app-origin`, `~/rekrutme-env.bak-app-origin`.
- ~~Decide the old `dev.rkrt.me`~~: made real staging on 2026-10-20 (S004).
- Recapture landing image `step-collect` (shows `app.rkrt.me`) (S003).
- Registry vs reports: README "Monitoring" lists Kuma + GlitchTip as if present; the registry shows neither, so the registry wins. Prod and dev now both run `6b28451`; the commits since `8d52e8f` were harness/e2e/docs plus two dev-only lines, so prod's runtime is unchanged.

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'pm2 ls | grep -w rekrutme; ss -tlnH | grep ":3160 "; git -C ~/rekrutme describe --tags; cut -d= -f1 ~/rekrutme/.env | tr "\n" " "; ls ~/.pm2/logs/ | grep "^rekrutme"'
ssh -o BatchMode=yes -o ConnectTimeout=15 -i ~/.ssh/devops devops@app 'curl -s http://10.0.0.5:3160/api/health; echo'
curl -sI https://rkrt.me/api/health | grep -i -E "^HTTP|strict-transport"; curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://app.rkrt.me/track/x
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'ls -l /etc/nginx/sites-enabled/rkrt.me.conf; certbot certificates --cert-name rkrt.me 2>/dev/null | grep -E "Domains|Expiry"'
ssh -o BatchMode=yes -o ConnectTimeout=15 root@db "sudo -u postgres psql -XAt -d rekrutme -c 'select count(*) from drizzle.__drizzle_migrations' -c \"select nspname from pg_namespace where nspname in ('drizzle','pgboss')\""
ssh -o BatchMode=yes -o ConnectTimeout=15 root@backup 'ls -l /root/backups/pg/rekrutme/ | tail -3'
```
