# Dev Server Sysadmin Reports

Session-based sysadmin reports for `root@dev` (154.26.130.96 — KVM VPS, Ubuntu 22.04.5 LTS).

Multi-tenant development host: 5 user workloads (root, deploy, sabbi, hopis, maxbiz) plus a Frappe/ERPNext docker stack. Hosts dev environments for grobiz, hoteru, iccn, pasarbesar, pahala, rekrutme, teamy, wagrab, miaw-flow, feyfa, wabacall, and more.

| Session                                | Date       | Topic                          | Status |
|----------------------------------------|------------|--------------------------------|--------|
| [Session 1](session-001-2026-05-17.md) | 2026-05-17 | Initial server audit           | Done   |
| [Session 2](session-002-2026-05-25.md) | 2026-05-25 | Fluent Bit install — PM2 logs → OpenObserve (`dev` stream, 7d retention) | Done   |
| [Session 3](session-003-2026-06-17.md) | 2026-06-17 | Swap saturation — staggered PM2 restart (reclaimed 3.7 G swap) + grew swap 6→8 G + `max_memory_restart` caps (24/38 apps; relaunched 3 next-server leakers to exec directly) | Done   |
