#!/usr/bin/env bash
# Daily alert digest: refresh the ledger (pull.sh, read-only), then send ONE
# summary message to the alert chat via digest.py. Runs on `monitor` from
# /etc/cron.d/telegram-digest (see README.md "Daily digest"); safe to run by hand.
#   ./digest.sh --dry-run    refresh the ledger, print the message, send nothing
#   ./digest.sh --scheduled  cron mode: fires hourly but exits silently unless it
#                            is >= 08:00 WIB and no digest went out yet today (WIB
#                            date) — DST-proof (cron here has no CRON_TZ) and
#                            self-healing (a missed/failed run retries next hour)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

if [[ "${1:-}" == "--scheduled" ]]; then
  shift
  hour="${DIGEST_TEST_HOUR:-$(TZ=Asia/Jakarta date +%-H)}"; today="$(TZ=Asia/Jakarta date +%F)"
  last="$(jq -r '.digest.last_end // 0' "$DIR/state.json")"
  last_day="$(TZ=Asia/Jakarta date -d "@$last" +%F 2>/dev/null || TZ=Asia/Jakarta date -r "$last" +%F)"
  if [[ "$hour" -lt 8 || "$last_day" == "$today" ]]; then exit 0; fi
  echo "[$(date -u +%FT%TZ)] scheduled digest run"
fi

pull_out="$(mktemp)"; gaps="$(mktemp)"
trap 'rm -f "$pull_out" "$gaps"' EXIT

"$DIR/pull.sh" >"$pull_out" 2>&1
pull_rc=$?
# Anything pull.sh printed other than "[src] pulled N events" is a data gap.
grep -vE '^\[[a-z:]+\] (pulled [0-9]+ events|no new events)' "$pull_out" > "$gaps" || true
[[ $pull_rc -ne 0 ]] && echo "pull.sh exited $pull_rc" >> "$gaps"

DIGEST_GAPS_FILE="$gaps" python3 "$DIR/digest.py" "$@"
