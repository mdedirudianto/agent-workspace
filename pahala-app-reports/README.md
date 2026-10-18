# pahala-app-reports

App-scoped reports for **Pahala.co** (`pahala.co`) — a WhatsApp-based donation platform for Indonesia
(github.com/biji-dev/pahala, local `~/Projects/pahala`). Donors give to verified campaigns through a WhatsApp
conversation (state machine, optional WhatsApp Flows); payments go through **Midtrans** (QRIS, GoPay, VA); an admin
dashboard manages organizations, campaigns, donations and donors.

**Status: LIVE (sandbox payments) since 2026-10-18** (session-001): `v0.8.0` @ `8d7458a` at **`https://pahala.co`**.
Pre-release: it exists in production so the payment gateway has a real URL. **Midtrans is in sandbox** until the
production merchant account is activated. Owner items left: register webhook URLs, Uptime Kuma monitor, collect the
admin password. Staging `dev.pahala.co` is separate and unchanged.

Single Next.js 16 app (App Router, React 19, TypeScript, **npm**), Prisma 7 + Postgres, Auth.js v5 credentials admin
login, Tailwind 4 + shadcn/ui. **No Redis.** External: **Midtrans**, **WhatsApp Cloud API** (Meta), DigitalOcean Spaces.

## Deploy footprint

**No Docker in production.** Bare-metal Node 22 + PM2.

- **App:** `app` (`devops@154.26.129.104` / `10.0.0.5`), `/home/devops/pahala`; PM2 `pahala` (fork, **1 instance**),
  `next start -H 10.0.0.5 -p 3170`, nvm Node 22, `ecosystem.config.cjs` (server-local, `merge_logs`). Secrets in `.env` (600).
- **DB:** `db` (`10.0.0.1`), Postgres 16.9 `pahala`, owner role `pahala`; 2 Prisma migrations; **no seed in production**.
- **Proxy:** `proxy` vhost `pahala.co.conf` (`pahala.co`; `www` and HTTP 301 to the apex), LE cert `pahala.co` (apex + www,
  **HTTP-01 webroot**, no CF token → "Always Use HTTPS" must stay off), CF real-IP restore, webhook rate limit.
- **DNS:** Cloudflare zone `pahala.co` (account BIJI), orange-cloud, **Full (strict)**; `dev` / `*.dev` stay on `dev`.
- **Monitoring:** `/api/health` (200 only with the DB connected); logs via fluent-bit PM2 glob; nightly dump by `backup` Tier-2 auto-discovery.

## Sessions

| # | Date | Topic |
| --- | --- | --- |
| [001](session-001-2026-10-18.md) | 2026-10-18 | First production deploy: `app`/`db` + `proxy` vhost + LE cert, sandbox Midtrans, smoke test, first admin |

## Open follow-ups

See session-001 → "Open follow-ups" (webhook registration, Uptime Kuma, admin password pickup + file delete, privacy/terms pages, Midtrans go-live switch, `verifyWebhookSignature` 500, dev Midtrans key form).
