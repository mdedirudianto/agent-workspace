---
name: static-deploy-to-proxy
description: Use when shipping a built static site or SPA (dist/, Vite, Astro, PWA) to /var/www on the biji proxy host, especially when the build lives on app, which cannot SSH to proxy.
---

# Static deploy to proxy

**Core principle:** verify the replacement before anything live is touched. The live directory is swapped by rename and never emptied first. Two past incidents: an `rm -rf` before a corrupt tar caused a 90 s 403 (avilia), and an empty stage plus `rsync --delete` caused a 403 on order.gro.biz.id (grobiz S058).

**Check first:** if the repo ships a relay script (e.g. grobiz `relay-static.sh`) and the profile says it's live, use it. The profile at `docs/fleet/profiles/<app>.md` names the source dir, the root, the owner and modes, the API host the bundle must contain, and whether `relay-static` is cleared for use.

## Relay: app → Mac → proxy

Run from the Mac. Keep the stage in the session scratchpad.

1. **Identify (read-only).** On app, the build dir's repo SHA = `origin/main`, the tree is clean, `index.html` exists, and `dist` is newer than HEAD. Grep the bundle for the API host: it must be the profile's prod host, not dev or central. For hoteru instances, each instance has its own API.
2. **Pull.** Send the tar stream in its own SSH call: `ssh devops@app "tar czf - -C $DIST ." > $STAGE/b.tgz`. Nothing else may print to stdout in that call. Never use `ssh -n` inside `rsync -e`. Then `tar tzf` the archive, extract it, and compare the per-file sha256 list with the one app produces.
3. **Baseline on proxy (read-only).** Note the live entry asset, owner and modes, the vhost `root`, and that no stale `.staging`/lock dir exists.
4. **Stage on proxy (write, needs approval).** `scp` the tgz to `/tmp`, extract it into `<root>.staging-<TS>`, compare the hash list again, then set the owner and modes to match the live dir.
5. **Swap (same approval).** In one SSH call: `mv <root> <root>.prev-<TS> && mv <root>.staging-<TS> <root>`. No nginx reload is needed.
6. **Verify.** `index.html` names the new entry asset, that asset returns 200 with a JS content type, SPA deep links return 200, and neighbouring sites on proxy are unaffected. Then run a browser check: no console errors, and API calls go to the right host.
7. **Rollback** is the reverse rename. Keep only the newest `.prev` per site (16 stale dirs existed on 2026-10-19). Delete older ones only with approval.

## Mac gotchas

- macOS openrsync has no `--chown`. Set the owner on proxy afterwards.
- `rsync --delete` is allowed only into a staging dir, never into the live root.
- The hash pipelines must match: Linux `sha256sum`, Mac `shasum -a 256`, both sorted by path.
