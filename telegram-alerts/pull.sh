#!/usr/bin/env bash
# Pulls new Telegram-alert events from all known sources into ledger.jsonl.
# Read-only against every remote host. Safe to re-run — each source has its
# own checkpoint in state.json, so a run only fetches what's new since the
# last pull. See README.md for source details and the ledger schema.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEDGER="$DIR/ledger.jsonl"
STATE="$DIR/state.json"
ENV_FILE="$HOME/.config/telegram-alerts/.env"

append() { printf '%s\n' "$1" >> "$LEDGER"; }

# usage: state_get '<jq filter using $n etc>' [--arg n "value" ...]
state_get() {
  local filter="$1"; shift
  jq -r "$@" "$filter" "$STATE"
}

# usage: state_set '<jq filter using $v etc>' --arg v "value" [more jq args...]
state_set() {
  local filter="$1"; shift
  local tmp; tmp="$(mktemp)"
  if jq "$@" "$filter" "$STATE" > "$tmp"; then
    mv "$tmp" "$STATE"
  else
    rm -f "$tmp"
    echo "[state] failed to update state.json (filter: $filter)" >&2
  fi
}

# ---------------------------------------------------------------------------
# Kuma — down/up transitions for all monitors (incl. push-type canaries)
# ---------------------------------------------------------------------------
pull_kuma() {
  local checkpoint rows count=0 new_checkpoint=""
  checkpoint="$(state_get '.kuma')"

  rows="$(ssh root@monitor "docker exec uptime-kuma mariadb -N -u root -S /app/data/run/mariadb.sock kuma -e \"SELECT h.time, m.name, h.status, h.msg FROM heartbeat h JOIN monitor m ON h.monitor_id=m.id WHERE h.important=1 AND h.time > '$checkpoint' ORDER BY h.time\"" 2>/dev/null)"
  if [[ $? -ne 0 ]]; then
    echo "[kuma] SSH/query failed — skipped"
    return
  fi
  if [[ -z "$rows" ]]; then
    echo "[kuma] no new events"
    return
  fi

  while IFS=$'\t' read -r time name status msg; do
    [[ -z "$time" ]] && continue
    local ts status_word
    ts="${time/ /T}Z"
    status_word="down"; [[ "$status" == "1" ]] && status_word="up"
    append "$(jq -nc --arg ts "$ts" --arg monitor "$name" --arg status "$status_word" --arg msg "$msg" \
      '{ts:$ts, source:"kuma", monitor:$monitor, status:$status, msg:$msg}')"
    new_checkpoint="$time"
    count=$((count + 1))
  done <<< "$rows"

  if [[ -n "$new_checkpoint" ]]; then
    state_set '.kuma = $v' --arg v "$new_checkpoint"
  fi
  echo "[kuma] pulled $count events"
}

# ---------------------------------------------------------------------------
# Backup — notify.sh failures, already logged locally on `backup`
# ---------------------------------------------------------------------------
pull_backup() {
  local checkpoint lines count=0 new_checkpoint
  checkpoint="$(state_get '.backup')"
  new_checkpoint="$checkpoint"

  lines="$(ssh root@backup "grep '\[ALERT\]' /var/log/backup.log" 2>/dev/null)"
  if [[ $? -gt 1 ]]; then
    echo "[backup] SSH failed — skipped"
    return
  fi
  if [[ -z "$lines" ]]; then
    echo "[backup] no alert lines found"
    return
  fi

  while IFS= read -r line; do
    # format: [ALERT] 2026-08-02 20:00 WIB <message...>
    local rest ts_raw msg ts
    rest="${line#\[ALERT\] }"
    ts_raw="${rest:0:16}"   # "2026-08-02 20:00"
    msg="${rest:21}"        # after "YYYY-MM-DD HH:MM WIB "
    [[ "$ts_raw" > "$checkpoint" ]] || continue
    ts="${ts_raw/ /T}:00+07:00"
    append "$(jq -nc --arg ts "$ts" --arg msg "$msg" '{ts:$ts, source:"backup", host:"backup", msg:$msg}')"
    new_checkpoint="$ts_raw"
    count=$((count + 1))
  done <<< "$lines"

  if [[ "$new_checkpoint" != "$checkpoint" ]]; then
    state_set '.backup = $v' --arg v "$new_checkpoint"
  fi
  echo "[backup] pulled $count events"
}

# ---------------------------------------------------------------------------
# OpenObserve — 4 scheduled log alerts, polled via last_triggered_at
# ---------------------------------------------------------------------------
pull_openobserve() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "[openobserve] $ENV_FILE not found — skipped (see README.md Credentials)"
    return
  fi
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  if [[ -z "${OO_USER:-}" || -z "${OO_PASS:-}" ]]; then
    echo "[openobserve] OO_USER/OO_PASS not set in $ENV_FILE — skipped"
    return
  fi

  local resp count=0
  # NOTE: this OO instance's alerts API is v2 (folder-scoped alerts), not the
  # plain /api/{org}/alerts path some OO docs show — confirmed live 2026-08-03.
  resp="$(curl -s -m 10 -u "${OO_USER}:${OO_PASS}" "https://observe.biji.uk/api/v2/default/alerts")"
  if [[ -z "$resp" ]] || ! echo "$resp" | jq -e . >/dev/null 2>&1; then
    echo "[openobserve] request failed or returned non-JSON — skipped"
    return
  fi

  local names
  names="$(echo "$resp" | jq -r '.list[]?.name // empty')"
  if [[ -z "$names" ]]; then
    echo "[openobserve] no alerts returned (unexpected response shape?) — response saved to /tmp/oo-alerts-debug.json"
    echo "$resp" > /tmp/oo-alerts-debug.json
    return
  fi

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local last_satisfied_us checkpoint ts
    # last_triggered_at advances on every scheduled evaluation (every 5min for
    # all 4 alerts here) regardless of whether the condition was met — using it
    # would log a false "fired" event every cycle. last_satisfied_at is the
    # field that only advances when the condition was actually true (i.e. the
    # alert really fired to Telegram) — confirmed live 2026-08-03 by comparing
    # both fields across a poll interval.
    last_satisfied_us="$(echo "$resp" | jq -r --arg n "$name" '.list[] | select(.name==$n) | .last_satisfied_at // empty')"
    [[ -z "$last_satisfied_us" || "$last_satisfied_us" == "null" ]] && continue
    checkpoint="$(state_get '.openobserve[$n]' --arg n "$name")"
    [[ "$last_satisfied_us" == "$checkpoint" ]] && continue

    ts="$(date -u -r "$((last_satisfied_us / 1000000))" +%Y-%m-%dT%H:%M:%SZ)"
    append "$(jq -nc --arg ts "$ts" --arg alert "$name" --arg lt "$last_satisfied_us" \
      '{ts:$ts, source:"openobserve", alert:$alert, last_satisfied_at:$lt}')"
    state_set '.openobserve[$n] = $v' --arg n "$name" --arg v "$last_satisfied_us"
    count=$((count + 1))
  done <<< "$names"

  echo "[openobserve] pulled $count events"
}

# ---------------------------------------------------------------------------
# Netdata — health alarm transitions across all 5 hosts, via each host's
# local health-log SQLite DB (no HTTP API exposes history, only current state)
# ---------------------------------------------------------------------------
NETDATA_HOSTS=(app db proxy erp monitor)
NETDATA_DB="/var/cache/netdata/netdata-meta.db"

# Status codes (netdata RRDCALC_STATUS): -2 REMOVED, -1 UNDEFINED, 0 UNINITIALIZED,
# 1 CLEAR, 2 WARNING, 3 CRITICAL. Only WARNING/CRITICAL and CLEAR-after-WARNING/
# CRITICAL (recovery) are notification-worthy; UNINITIALIZED/REMOVED churn is
# excluded in the SQL itself so it never hits the ledger.
netdata_status_word() {
  case "$1" in
    2) echo "WARNING" ;;
    3) echo "CRITICAL" ;;
    *) echo "CLEAR" ;;
  esac
}

pull_netdata() {
  local host checkpoint rows count total=0
  for host in "${NETDATA_HOSTS[@]}"; do
    checkpoint="$(state_get '(.netdata // {})[$h] // 0' --arg h "$host")"

    rows="$(ssh "root@$host" "python3 -c \"
import sqlite3
con = sqlite3.connect('file:$NETDATA_DB?mode=ro', uri=True)
cur = con.cursor()
cur.execute('SELECT d.when_key, l.name, l.chart, d.old_status, d.new_status, d.summary FROM health_log_detail d JOIN health_log l ON d.health_log_id = l.health_log_id WHERE d.when_key > $checkpoint AND (d.new_status IN (2,3) OR (d.new_status = 1 AND d.old_status IN (2,3))) ORDER BY d.when_key')
for r in cur.fetchall():
    print('\t'.join(str(x) for x in r))
\"" 2>/dev/null)"
    if [[ $? -ne 0 ]]; then
      echo "[netdata:$host] SSH/query failed — skipped"
      continue
    fi
    if [[ -z "$rows" ]]; then
      echo "[netdata:$host] no new events"
      continue
    fi

    count=0
    local new_checkpoint="$checkpoint"
    while IFS=$'\t' read -r when name chart old new summary; do
      [[ -z "$when" ]] && continue
      local ts status_word
      ts="$(date -u -r "${when%.*}" +%Y-%m-%dT%H:%M:%SZ)"
      status_word="$(netdata_status_word "${new%.*}")"
      append "$(jq -nc --arg ts "$ts" --arg host "$host" --arg alarm "$name" --arg chart "$chart" --arg status "$status_word" --arg msg "$summary" \
        '{ts:$ts, source:"netdata", host:$host, alarm:$alarm, chart:$chart, status:$status, msg:$msg}')"
      new_checkpoint="$when"
      count=$((count + 1))
      total=$((total + 1))
    done <<< "$rows"

    if [[ "$new_checkpoint" != "$checkpoint" ]]; then
      state_set '.netdata[$h] = ($v | tonumber)' --arg h "$host" --arg v "$new_checkpoint"
    fi
    echo "[netdata:$host] pulled $count events"
  done
  echo "[netdata] pulled $total events total"
}

main() {
  pull_kuma
  pull_backup
  pull_openobserve
  pull_netdata
}

main "$@"
