# Pasarbesar App Reports

Session-based reports for the **pasarbesar** product (Next.js marketplace family on `app` server). App-scoped, not server-scoped: cross-server changes that revolve around this app (proxy + app + DB, env/domain rotation, version bumps, schema changes) belong here. Routine server-only work stays in the server's own `*-sysadmin-reports/`.

Apps in this family:

- `pasarbesar` — main site, port `7002` on `10.0.0.5`, served at `pasarbesar.id` / `www.pasarbesar.id` / `beta.pasarbesar.id`.
- `pasarbesar-lpekinhub` — variant instance, port `7003` on `10.0.0.5`, served at `lpekinhub.pasarbesar.id` (since session 1; previously `lpekinhubjatim.faazdigi.com`).

| Session                                | Date       | Topic                                                       | Status |
|----------------------------------------|------------|-------------------------------------------------------------|--------|
| [Session 1](session-001-2026-05-21.md) | 2026-05-21 | Rotate lpekinhub domain → `lpekinhub.pasarbesar.id`         | Done   |
| [Session 2](session-002-2026-05-21.md) | 2026-05-21 | Align both PM2 entries with `output: "standalone"` (new std) | Done   |
