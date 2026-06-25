# wabacall App Reports

App-scoped reports for the **wabacall** product — a WhatsApp Business Calling API bridge (two-leg WebRTC bridge between a browser and the WhatsApp Cloud API for inbound + outbound voice calls, with per-call recording, optional transcription, and an AI voice agent pipeline).

Covers cross-server work: the wabacall service on `dev`, its public ingress, and Meta webhook routing through the shared `miaw-route` router.

**Server footprint:**
- `dev` (`154.26.130.96`) — wabacall service under PM2 (`deploy` user), `node server.js` on `0.0.0.0:19000`; source at `/home/deploy/wabacall`. Public ingress `wabacall.dev.biji.uk` (nginx → `localhost:19000`, wildcard `*.dev.biji.uk` LE cert).
- `app` (`154.26.129.104` / `10.0.0.5`) — production `miaw-route` (systemd/Bun `:9001`, `routes.biji.uk`) holds the route that forwards this number's webhooks to wabacall.
- `db` (`10.0.0.1`) — `miaw_route` Postgres DB where the route row lives.

**Meta identity:** app **BIJI Dev** (`APP_ID 1125824895132994`), `PHONE_NUMBER_ID 109689798856637`, `WABA_ID 100405506465612` — a number shared with PasarBesar on the same Meta app. Meta subscription points at `https://routes.biji.uk/webhook/d7745f14-1e19-4836-8ca1-866ed58cb4d6` (fields `calls` + `messages`).

**Open follow-ups:**
- [ ] Commit the `start-tunnel.sh --update-meta` guard in the wabacall repo (currently an uncommitted working-tree edit locally; dev copy patched in place) and redeploy.
- [ ] Live end-to-end call test: confirm a real inbound/outbound call for `109689798856637` lands in prod miaw-route `webhook_logs` and reaches wabacall (deferred to user / miaw-route side).
- [ ] Decide whether the now-idle `wabacall-tunnel` machinery (cloudflared) should be fully removed from the repo, or kept as a documented local-dev-only path.
- [ ] Messages for `109689798856637` are delivered to wabacall (single primary route) and ignored — revisit with a `fan_out` split if a prod messages consumer is ever added for this number.

## Sessions

| # | Date | Topic | Key outcomes |
|---|------|-------|-------------|
| [001](session-001-2026-06-10.md) | 2026-06-10 | Migrate Meta connection from direct tunnel → miaw-route | Created `wabacall.dev.biji.uk` nginx ingress; deleted `wabacall-tunnel`; added prod miaw-route route (`109689798856637` → `wabacall.dev.biji.uk/call-events`); confirmed Meta already on miaw-route (no change); disabled `start-tunnel.sh --update-meta` |
