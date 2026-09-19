#!/usr/bin/env bash
# Copy the authoritative ledger + state from `monitor` (where cron runs pull.sh /
# digest.sh) down to this checkout. One-way and read-only against monitor.
# After this, `python3 digest.py --dry-run --hours 24` previews a digest locally.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rsync -a root@monitor:/opt/telegram-alerts/ledger.jsonl root@monitor:/opt/telegram-alerts/state.json "$DIR/"
echo "synced: $(wc -l < "$DIR/ledger.jsonl") ledger rows; last digest: $(jq -r '.digest.last_end // 0 | todate' "$DIR/state.json")"
