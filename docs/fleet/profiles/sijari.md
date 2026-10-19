# sijari — profile

**Profile version:** 1 · **Stamped:** 2026-10-19 · **Sources:** sijari-app-reports up to session-005 (2026-10-16), registry + proxy host survey 2026-10-19, repo `biji-ext/sijari-web` at `b50534c` (local `main` = `origin/main` = prod)
**Rule:** a profile is a pointer plus the facts a deploy needs. When a repo doc owns a procedure, link it and don't copy it. Bump the version and stamp when you change this file.

## Owner docs
- Repo `~/Projects/sijari-web`: `README.md` ("Deploying": what to copy and leave out), `CLAUDE.md` (CSP in `deploy/sijari.uk.conf`, local CSP testing, asset generators), `deploy/sijari.uk.conf` (full HTTPS server: headers, CSP, caching) and `deploy/sijari.uk.http.conf` (port-80 bootstrap for certbot).
- **The staged deploy command (exclude list, file count, swap, rollback) is owned by the workspace**: [session-004 "Redeploy (updated)"](../../../sijari-app-reports/session-004-2026-10-06.md), confirmed unchanged in [session-005](../../../sijari-app-reports/session-005-2026-10-16.md). Skill `static-deploy-to-proxy` covers the generic stage → verify → swap.
- Workspace: [README](../../../sijari-app-reports/README.md), sessions 005, 004, 003 (shop buttons), 002 (BOS Putih redesign, CF purge lesson).

## Footprint
| Surface | Host | Process / root | Bind | Domain(s) | TLS |
|---|---|---|---|---|---|
| static site | proxy | nginx, files `/var/www/sijari.uk` (`www-data`, **24 files**, 3.4 MB, 10-19) | 443 | `sijari.uk` | cert `sijari.uk` (apex + www), **HTTP-01 webroot** `/var/www/certbot`, exp **2026-12-25**, **no reload hook** |
| www | proxy | same vhost | 443 | `www.sijari.uk` → 301 apex | same |
| port 80 | proxy | ACME webroot + 301 https | 80 | both | — |
| rollback copy | proxy | `/var/www/sijari.uk.prev` = the `a3ffa19` site (24 files) | — | not served | — |

- vhost `/etc/nginx/sites-available/sijari.uk.conf`, symlinked into `sites-enabled` (sha256 `36840c90…`, unchanged since s003).
- Cloudflare **orange-cloud**, SSL **Full (strict)**. **No Cloudflare API token exists for this zone** (no DNS-01, no scripted purge).
- No app, DB, Redis, cookies, forms or cart. One same-origin script: `assets/gate.js` (21+ age gate; without JS the page stays inert by design).
- Purchase buttons ("Pesan") link out to `https://sijari.gro.biz.id/shop` (a grobiz tenant shop).

## Data
- None server-side. The source of truth is the git repo; the live tree is a copy of it minus the excludes.
- Not backed up by `backup` (static files only; the repo is the backup).

## Deploy
- Mode: **static relay from the Mac** (fresh clone of `biji-ext/sijari-web` → rsync to `/var/www/sijari.uk.new` on proxy → hash check → swap). Registry calls it "Mode B".
- Before planning: compare `git rev-parse HEAD` with `git ls-remote origin main`. The deploy clones the remote, so unpushed commits are invisible (s005).
- Follow session-004's command verbatim. It excludes `.git`, **`.remember`**, `.playwright-mcp`, `tools`, `deploy`, docs, source images and the orphaned pack images. Expect **24 files, 0 dotfiles**, then compare sha256 of every file with the clone.
- Swap: delete the old `.prev`, move live → `.prev`, move `.new` → live. Never delete the live tree before the new one is verified (memory: never delete before verifying the replacement).
- nginx change: copy `deploy/sijari.uk.conf`, back up the old file (not inside `sites-enabled/`), `nginx -t && systemctl reload nginx`.
- CSS change: purge `https://sijari.uk/assets/style.css` in the Cloudflare dashboard right after the swap (no token; edge TTL ~4 h) (s002).
- Rollback: `cd /var/www && mv sijari.uk sijari.uk.bad && mv sijari.uk.prev sijari.uk` (no nginx change needed) (s004, s005).
- `git push` from this workspace is blocked by the auto-mode classifier; the user runs `! git push origin main` (s005).

## Verify (after deploy)
- Origin (`curl --resolve sijari.uk:443:46.250.234.153`) and edge serve the same sha256 as the repo for `/`, `style.css` and any changed asset.
- 200: `/`, `/robots.txt`, `/sitemap.xml`, `/assets/style.css`, `merak-hitam-16.webp`. 404: `/.git/config`, `merak-hitam-12.webp`, `sjr-hitam.webp`, `surprise.jpeg`. `www` → 301 apex.
- Headers present: CSP (`script-src 'self'`), HSTS 1 y, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`.
- Browser (desktop 1366, mobile 390): 7 packs, 7 "Pesan" buttons, no 4xx, no horizontal scroll. **Scroll each `.shelf img` into view before checking `naturalWidth`** (lazy-loaded, s004).
- Logs: proxy `/var/log/nginx/access.log` / `error.log` (shared, shipped to OpenObserve `nginx`). Kuma: **none** (gap). GlitchTip/OpenPanel: none.

## Known noise
- One console error per page load: Cloudflare's auto-injected Web Analytics beacon blocked by the CSP (s001–s005).
- Playwright's own profile can cache old CSS; use a fresh context (s002).
- Search engines may keep the old street address in snippets until recrawled (s005).

## Smoke test
- Safe: everything in Verify; it's all GETs.
- Don't: overlay-rsync into the live dir, or rsync without the excludes (`.remember/` shipped once, s001). Don't turn on Cloudflare "Always Use HTTPS" for the zone: HTTP-01 renewal needs plain port 80.

## Gotchas
1. The Remember plugin writes `.remember/` inside the project; it was rsynced to production once and removed before the vhost existed (s001).
2. Asset filenames aren't fingerprinted. Rename a replaced image or font, and purge `style.css` after CSS changes (s001, s002).
3. Cloudflare served stale CSS for up to 4 h after a deploy; only a dashboard purge fixed it (s002).
4. The exclude list changes when products come and go. Restoring Merak Hitam 16 meant removing it from the excludes; production count went 23 → 24 (s004).
5. Lazy-loaded shelf images give a false "image missing" in headless checks (s004).
6. The local repo was 2 commits ahead of the remote; the fresh-clone deploy would have shipped the old site (s005).
7. Adding a subdomain means re-issuing the cert with another `-d` (HTTP-01, no wildcard) (README).

## Open items
- **Drift (CLAUDE.md):** says "no repo yet, source at `~/Projects/sijari-uk/` (local only)" and "strict CSP (`script-src 'none'`)". Truth: repo `github.com/biji-ext/sijari-web`, local `~/Projects/sijari-web/` (s002 onward); CSP is `script-src 'self'` since s002 (age gate). The registry's "fresh clone of `biji-ext/sijari-web`" is right.
- **Cert renews about 2026-11-25.** The proxy deploy hook (10-19, proxy S008) reloads nginx, so check the served serial afterwards (registry §6, §10).
- No Kuma monitors for `https://sijari.uk/` or the shop target `https://sijari.gro.biz.id/shop` (README; monitor survey gap list).
- CF Web Analytics beacon vs CSP: disable the zone's auto-setup or allow `static.cloudflareinsights.com` (README).
- Delete `/var/www/sijari.uk.prev` once the owner is happy; decide the video (smoking-scene cut is live); `git rm` the two orphaned pack images; keep source images out of `assets/`; optional `/kemitraan` redirect; contact/partner route undecided (README).

## Verify live
```bash
ssh -o BatchMode=yes -o ConnectTimeout=15 root@proxy 'find /var/www/sijari.uk -type f | wc -l; ls -d /var/www/sijari.uk*; sha256sum /etc/nginx/sites-available/sijari.uk.conf; readlink /etc/nginx/sites-enabled/sijari.uk.conf; certbot certificates 2>/dev/null | grep -A2 "Name: sijari.uk"'
git -C ~/Projects/sijari-web rev-parse --short HEAD; git ls-remote https://github.com/biji-ext/sijari-web.git main
curl -sI https://sijari.uk/ | grep -i -E "^HTTP|content-security|strict-transport"; curl -s -o /dev/null -w '%{http_code}\n' https://www.sijari.uk/
curl -s https://sijari.uk/ | shasum -a 256; git -C ~/Projects/sijari-web show HEAD:index.html | shasum -a 256
```
