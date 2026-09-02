# maxchat App Reports

App-scoped reports for the **Maxchat v4** product (`v4.maxchat.id`) — the landing page for Max, an AI product that reads a business's existing systems and answers questions in plain language with a receipt on every number.

**Repo:** `github.com/biji-dev/max` (pnpm + turbo monorepo). Apps: `landing` (Astro 7 + React 19 islands, fully static, no adapter/server code — waitlist form hands off to a WhatsApp deep link, optional `PUBLIC_WAITLIST_ENDPOINT` webhook unset/unused in prod). Packages: `tokens` (design tokens as CSS custom properties), `config` (shared tsconfig base). Not related to the older `~/Projects/maxchat/` 8-app ecosystem (no git remote, separate codebase).

**Server footprint:**
- `app` (`154.26.129.104` / `10.0.0.5`) — build-only. Source at `~/max` (devops). No PM2 process — the app has no server component.
- `proxy` (`46.250.234.153`) — public nginx; terminates TLS for `v4.maxchat.id`. Serves the Astro static build from `/var/www/v4.maxchat.id`. **Grey-cloud DNS (direct A record to proxy, not CF-proxied)**; LE cert via HTTP-01 (`certbot certonly --webroot -w /var/www/certbot`).

**Current deployed SHA:** `d09a9a1` (main, 2026-09-02). Deployed session-001.

## Sessions

| Session | Date | Topic |
| --- | --- | --- |
| [session-001](session-001-2026-09-02.md) | 2026-09-02 | Initial production deploy — landing built on `app`, static output shipped to `proxy`, nginx + LE TLS for `v4.maxchat.id` |
