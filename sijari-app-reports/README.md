# sijari-app-reports

App-scoped reports for **sijari** — the SIJARI Indonesia info/catalogue site at **`sijari.uk`** (an Indonesian
kretek / "rempah hisap" brand, tagline *Alam punya rasa*). Pure static site: **no backend, database, cookies,
forms or JavaScript**, and deliberately **no cart or ordering flow** — information and products only.

**No repo yet.** Source lives at `~/Projects/sijari-uk/` (local only): `index.html`, `404.html`,
`assets/` (CSS, WebP images, self-hosted fonts), `deploy/` (nginx configs), `tools/make-images.py`.

## Deploy footprint (production, since session-001)

- **Host:** `proxy` only (`root@46.250.234.153` / `10.0.0.2`). Files at `/var/www/sijari.uk` (`www-data`),
  vhost `/etc/nginx/sites-available/sijari.uk.conf` (symlinked into `sites-enabled`).
- **DNS:** Cloudflare, **orange-cloud**, SSL/TLS **Full (strict)**. `sijari.uk` + `www` → origin `proxy`.
- **TLS:** one LE cert (2 names) via **HTTP-01 webroot** (`/var/www/certbot`), expires **2026-12-25**.
  **Not a wildcard, and no Cloudflare API token exists for this zone** — a new subdomain means re-issuing with
  an extra `-d`. "Always Use HTTPS" on the zone would break renewal (→ DNS-01).
- **Hosts:** apex serves the site; `www` 301s to the apex; port 80 → 301 https (except ACME).
- **Headers:** strict CSP (`script-src 'none'`, all assets self-hosted), HSTS 1 y, `nosniff`, `DENY`.
  Caching: HTML revalidates, `/assets/` 30 d, `style.css` 1 h (Cloudflare serves CSS at 4 h). Asset
  filenames are **not fingerprinted** — rename an image/font if you replace it.
- **Design:** palette sampled from the logo (forest green + wordmark gold), Krona One + Literata, one
  load animation, reward ladder drawn as a log-scaled staircase.

## Redeploy

See "Redeploy" in [session-001](session-001-2026-09-26.md). Note the **`--exclude .remember`** — the Remember
plugin creates that directory inside the project and it must never be shipped.

## Open follow-ups

- [ ] **Cloudflare Web Analytics beacon is blocked by the strict CSP** (one console error per page load, no
      analytics). Disable the zone's automatic setup, or allow `static.cloudflareinsights.com` in the CSP.
- [ ] **Create a repo** and back up the source (currently only `~/Projects/sijari-uk/` + deployed copy).
- [ ] Add an Uptime Kuma monitor for `https://sijari.uk/`.
- [ ] Decide whether the page needs a contact / partner-onboarding route (the source's WhatsApp ordering flow
      was dropped by request).
- [ ] Optional `301 /kemitraan → /#kemitraan`.

## Sessions

| Session | Date | Topic | Status |
| --- | --- | --- | --- |
| [Session 1](session-001-2026-09-26.md) | 2026-09-26 | Redesigned static info site built from the SIJARI preview's content + logo palette, deployed on proxy — nginx vhost, 2-name LE cert (HTTP-01), strict CSP; repaired defective pack cutouts; `.remember/` accidentally rsynced and removed before going live | Done |
