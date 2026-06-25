# ERP Server Sysadmin Reports

Session-based sysadmin reports for `root@erp` (217.15.166.117 public / 10.0.0.6 internal — KVM VPS, Ubuntu 24.04.4 LTS).

Hosts **ERPNext v16 for `gro.biz.id`**, reverse-proxied from the `proxy` server. Database lives on the internal `db` server (`10.0.0.1`). Will be consumed by the future `grobiz` app on `app`.

| Session                                | Date       | Topic                                | Status |
|----------------------------------------|------------|--------------------------------------|--------|
| [Session 1](session-001-2026-05-17.md) | 2026-05-17 | Initial audit + same-day hardening   | Done   |
| [Session 2](session-002-2026-05-24.md) | 2026-05-24 | Fluent Bit install — Frappe logs → OpenObserve | Done   |
