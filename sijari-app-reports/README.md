# sijari-app-reports

App-scoped reports for **sijari** — the SIJARI Indonesia info/catalogue site at **`sijari.uk`** (an Indonesian
kretek / "rempah hisap" brand, tagline *Alam punya rasa*). Static site: **no backend, database, cookies or
forms**; the only JavaScript is the same-origin 21+ age gate (`assets/gate.js`), and deliberately **no cart or ordering flow** — information and products only.

**Repo:** `github.com/biji-ext/sijari-web` (`main`), local `~/Projects/sijari-web/`: `index.html`, `404.html`,
`assets/` (CSS, images, video, self-hosted fonts, `gate.js`), `deploy/` (nginx configs), `tools/`.

## Deploy footprint (production, since session-001)

- **Host:** `proxy` only (`root@46.250.234.153` / `10.0.0.2`). Files at `/var/www/sijari.uk` (`www-data`),
  vhost `/etc/nginx/sites-available/sijari.uk.conf` (symlinked into `sites-enabled`).
- **DNS:** Cloudflare, **orange-cloud**, SSL/TLS **Full (strict)**. `sijari.uk` + `www` → origin `proxy`.
- **TLS:** one LE cert (2 names) via **HTTP-01 webroot** (`/var/www/certbot`), expires **2026-12-25**.
  **Not a wildcard, and no Cloudflare API token exists for this zone** — a new subdomain means re-issuing with
  an extra `-d`. "Always Use HTTPS" on the zone would break renewal (→ DNS-01).
- **Hosts:** apex serves the site; `www` 301s to the apex; port 80 → 301 https (except ACME).
- **Headers:** strict CSP (`script-src 'self'` since session-002, all assets self-hosted), HSTS 1 y, `nosniff`, `DENY`.
  Caching: HTML revalidates, `/assets/` 30 d, `style.css` 1 h (Cloudflare serves CSS at 4 h). Asset
  filenames are **not fingerprinted** — rename an image/font if you replace it.
- **Design:** palette sampled from the logo (forest green + wordmark gold), redesigned in session-002 after the BOS Putih pack
  (Archivo + Sacramento, halftone Indonesia map, 21+ age gate).

## Redeploy

See "Redeploy" in [session-002](session-002-2026-09-30.md) (deploy from the repo, staged + swapped; purge `style.css` in Cloudflare after CSS changes). Note the **`--exclude .remember`** — the Remember
plugin creates that directory inside the project and it must never be shipped.

## Open follow-ups

- [ ] **Cloudflare Web Analytics beacon is blocked by the strict CSP** (one console error per page load, no
      analytics). Disable the zone's automatic setup, or allow `static.cloudflareinsights.com` in the CSP.
- [ ] Delete rollback copies on `proxy` (`sijari.uk.prev`, `sijari.uk.conf.bak-20260930`); decide the video (smoking-scene cut is live).
- [ ] Add an Uptime Kuma monitor for `https://sijari.uk/`.
- [ ] Decide whether the page needs a contact / partner-onboarding route (the source's WhatsApp ordering flow
      was dropped by request).
- [ ] Optional `301 /kemitraan → /#kemitraan`.

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 1](session-001-2026-09-26.md) | 2026-09-26 | Redesigned static info site built from the SIJARI preview's content + logo palette, deployed on proxy — nginx vhost, 2-name LE cert (HTTP-01), strict CSP; repaired defective pack cutouts; `.remember/` accidentally rsynced and removed before going live | Done |
| [Session 2](session-002-2026-09-30.md) | 2026-09-30 | Deployed the BOS Putih redesign + 21+ age gate from the remote repo (`biji-ext/sijari-web` @ `8980049`) — staged + swapped, CSP `script-src 'self'`; stale Cloudflare CSS fixed by manual purge | Done |
