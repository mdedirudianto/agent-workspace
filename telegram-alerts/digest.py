#!/usr/bin/env python3
"""Daily Telegram alert digest, built from ledger.jsonl.

Summarises everything since the last digest (default 24h, max 48h) into ONE
message: what needs a look, what is now digest-only (no longer paged live),
what was already paged live, and what never paged. Called by digest.sh, which
runs pull.sh first so the ledger is fresh.

The message is sent with the Netdata bot token in
/etc/netdata/health_alarm_notify.conf — directly when run on `monitor` (cron),
or over SSH to `monitor` from elsewhere — so no bot token lives on a laptop.

Usage:
    digest.py --dry-run          print the message, send nothing, don't move the window
    digest.py                    send, then advance the window in state.json
    digest.py --hours N          override the window (dry-run friendly)
    DIGEST_GAPS_FILE=path        lines of pull.sh warnings to surface as "data gaps"
"""
import argparse, collections, datetime as dt, json, os, subprocess, sys
from zoneinfo import ZoneInfo

DIR = os.path.dirname(os.path.abspath(__file__))
LEDGER = os.path.join(DIR, "ledger.jsonl")
STATE = os.path.join(DIR, "state.json")
TZ = ZoneInfo("Asia/Jakarta")
SEND_VIA = "root@monitor"
TG_LIMIT = 3900  # Telegram hard limit is 4096

# Alarms stock-routed `to: silent` in Netdata: they transition (so they land in
# the ledger) but never reach Telegram.
SILENT_STOCK = {
    "ml_1min_node_ar", "10s_ip_tcp_resets_sent", "10s_ip_tcp_resets_received",
    "1min_netdev_backlog_exceeded", "1min_netdev_budget_ran_outs",
    "10min_netisr_backlog_exceeded", "plugin_data_collection_status",
}
# Paged live until the 2026-09-20 noise cleanup; now digest-only.
DIGEST_ONLY_NETDATA = {
    ("proxy", "web_log_1m_bad_requests"), ("proxy", "web_log_1m_redirects"),
    ("proxy", "web_log_1m_unmatched"),
    ("db", "postgres_db_transactions_rollback_ratio"),
    ("db", "postgres_acquired_locks_utilization"),
}
DIGEST_ONLY_KUMA = {  # notification detached from these monitors 2026-09-20
    "ytgrab Direct Tier Canary", "ytgrab Datacenter Tier Canary",
    "ytgrab Residential Tier Canary",
}
# Before 2026-09-20 pull.sh labelled Netdata status 3 (WARNING) as "CRITICAL".
# Rows at or before these per-host checkpoints carry that wrong label.
MISLABEL_UNTIL = {"app": 1789820697, "db": 1789855710, "proxy": 1789856586,
                  "erp": 1789838888, "monitor": 1789622305}


def parse(ts):
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))


def fmt_dur(sec):
    m = int(round(sec / 60))
    if m < 1:
        return "<1m"
    if m < 60:
        return f"{m}m"
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m" if m else f"{h}h"


_NOW = [None]


def hhmm(t):
    """HH:MM in WIB, prefixed with the date when it isn't the digest's own day."""
    lt = t.astimezone(TZ)
    if _NOW[0] is not None and lt.date() != _NOW[0].astimezone(TZ).date():
        return lt.strftime("%d %b %H:%M")
    return lt.strftime("%H:%M")


def plural(n, word):
    return f"{n} {word}{'' if n == 1 else 's'}"


def load_rows(start, end):
    rows = []
    with open(LEDGER) as f:
        for line in f:
            try:
                r = json.loads(line)
                t = parse(r["ts"])
            except Exception:
                continue
            if start < t <= end:
                r["_t"] = t
                rows.append(r)
    rows.sort(key=lambda r: r["_t"])
    return rows


def episodes(events):
    """events: time-sorted [(t, is_bad, severity_rank)] -> list of dicts."""
    eps, cur = [], None
    for t, bad, sev in events:
        if bad:
            if cur is None:
                cur = {"start": t, "end": None, "worst": sev}
            else:
                cur["worst"] = max(cur["worst"], sev)
        elif cur is not None:
            cur["end"] = t
            eps.append(cur)
            cur = None
    if cur is not None:
        eps.append(cur)  # still open
    return eps


def summarise(rows, end):
    nd = collections.defaultdict(list)     # (host, alarm) -> events
    kuma = collections.defaultdict(list)   # monitor -> events
    other = []                             # backup / openobserve
    for r in rows:
        if r["source"] == "netdata":
            status = r["status"]
            ts_epoch = int(r["_t"].timestamp())
            if (status == "CRITICAL" and not r.get("backfill")
                    and ts_epoch <= MISLABEL_UNTIL.get(r["host"], 0)):
                status = "WARNING"
            sev = {"CLEAR": 0, "WARNING": 1, "CRITICAL": 2}[status]
            nd[(r["host"], r["alarm"])].append((r["_t"], status != "CLEAR", sev))
        elif r["source"] == "kuma":
            kuma[r["monitor"]].append((r["_t"], r["status"] == "down", r.get("msg", "")))
        else:
            other.append(r)
    return nd, kuma, other


def build(start, end, gaps):
    _NOW[0] = end
    rows = load_rows(start, end)
    nd, kuma, other = summarise(rows, end)
    win_h = (end - start).total_seconds() / 3600
    win = f"{win_h * 60:.0f}m" if win_h < 1 else f"{win_h:.0f}h"
    head = f"📋 Alert digest — {end.astimezone(TZ):%a %d %b %H:%M} WIB (last {win})"

    look, digest_only, paged, silent_n = [], [], [], 0
    silent_alarms = set()

    # ---- Netdata
    for (host, alarm), ev in sorted(nd.items()):
        if alarm in SILENT_STOCK:
            silent_n += len(ev)
            silent_alarms.add(alarm)
            continue
        eps = episodes([(t, b, s) for t, b, s in ev])
        if not eps:
            continue
        longest = max(((e["end"] or end) - e["start"]).total_seconds() for e in eps)
        crit = sum(1 for e in eps if e["worst"] == 2)
        is_open = eps[-1]["end"] is None
        label = f"{host} {alarm}"
        if (host, alarm) in DIGEST_ONLY_NETDATA:
            s = f"• {label}: {plural(len(eps), 'episode')}, longest {fmt_dur(longest)}"
            if is_open:
                s += f", OPEN since {hhmm(eps[-1]['start'])}"
            digest_only.append(s)
            continue
        s = f"{label} ×{len(eps)}" + (f" ({crit} CRIT)" if crit else "")
        paged.append(s)
        if is_open:
            look.append(f"• OPEN {label} since {hhmm(eps[-1]['start'])}"
                        f"{' (CRITICAL)' if eps[-1]['worst'] == 2 else ''}")
        elif crit:
            look.append(f"• CRITICAL {label}: {crit}×, longest {fmt_dur(longest)}")

    # ---- Kuma
    for mon, ev in sorted(kuma.items()):
        eps = episodes([(t, b, 1) for t, b, _ in ev])
        if not eps:
            continue
        longest = max(((e["end"] or end) - e["start"]).total_seconds() for e in eps)
        is_open = eps[-1]["end"] is None
        last_msg = next((m for _, b, m in reversed(ev) if b), "")
        if mon in DIGEST_ONLY_KUMA:
            s = f"• {mon}: {len(eps)} down/up, longest {fmt_dur(longest)}, now {'DOWN' if is_open else 'up'}"
            digest_only.append(s)
        else:
            paged.append(f"{mon} ×{len(eps)}")
            if is_open:
                look.append(f"• DOWN {mon} since {hhmm(eps[-1]['start'])}: {last_msg[:60]}")
            else:
                look.append(f"• {mon}: {len(eps)} down/up, longest {fmt_dur(longest)}")

    # ---- backup / OpenObserve (rare; list individually)
    for r in other:
        if r["source"] == "backup":
            look.append(f"• backup {hhmm(r['_t'])}: {r['msg'][:90]}")
        else:
            look.append(f"• OpenObserve {r.get('alert')} {hhmm(r['_t'])}")

    out = [head, ""]
    if gaps:
        out += ["⚠️ Data gaps (this digest may be incomplete):"] + [f"  {g[:100]}" for g in gaps[:3]] + [""]
    if not look and not digest_only and not paged:
        out.append("✅ Quiet — nothing to review.")
    if look:
        out += ["🔎 Needs a look"] + look + [""]
    else:
        out += ["✅ Nothing needs a look.", ""]
    if digest_only:
        out += ["📉 Digest-only (no longer paged live)"] + digest_only + [""]
    if paged:
        out += ["📨 Already paged live"] + ["• " + ", ".join(paged)] + [""]
    if silent_n:
        out += [f"🔇 Never paged: {silent_n} transitions ({len(silent_alarms)} silent alarms)"]
    msg = "\n".join(out).rstrip()
    if len(msg) > TG_LIMIT:
        msg = msg[:TG_LIMIT].rsplit("\n", 1)[0] + "\n… (truncated)"
    return msg


def send(text):
    """Post via the Netdata bot token in /etc/netdata/health_alarm_notify.conf:
    directly when running on a host that has it (monitor cron), otherwise over
    SSH to `monitor` (e.g. from the Mac)."""
    remote = (
        'set -e; eval "$(grep -E \'^(TELEGRAM_BOT_TOKEN|DEFAULT_RECIPIENT_TELEGRAM)=\' '
        '/etc/netdata/health_alarm_notify.conf)"; '
        'curl -sS --max-time 20 --data-urlencode "text@-" -d "chat_id=$DEFAULT_RECIPIENT_TELEGRAM" '
        '-d disable_web_page_preview=true "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"'
    )
    if os.access("/etc/netdata/health_alarm_notify.conf", os.R_OK):
        cmd = ["bash", "-c", remote]
    else:
        cmd = ["ssh", "-o", "ConnectTimeout=15", "-o", "BatchMode=yes", SEND_VIA, remote]
    p = subprocess.run(cmd, input=text, capture_output=True, text=True, timeout=60)
    try:
        ok = json.loads(p.stdout).get("ok") is True
    except Exception:
        ok = False
    if not ok:
        print(f"send failed (rc={p.returncode}): {p.stdout[:200]} {p.stderr[:200]}", file=sys.stderr)
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--hours", type=float)
    a = ap.parse_args()

    end = dt.datetime.now(dt.timezone.utc)
    with open(STATE) as f:
        state = json.load(f)
    if a.hours:
        start = end - dt.timedelta(hours=a.hours)
    else:
        last = state.get("digest", {}).get("last_end")
        start = dt.datetime.fromtimestamp(last, dt.timezone.utc) if last else end - dt.timedelta(hours=24)
        start = max(start, end - dt.timedelta(hours=48))

    gaps = []
    gf = os.environ.get("DIGEST_GAPS_FILE")
    if gf and os.path.exists(gf):
        gaps = [l.strip() for l in open(gf) if l.strip()]

    msg = build(start, end, gaps)
    if a.dry_run:
        print(msg)
        print(f"\n[dry-run] {len(msg)} chars, window {start:%F %T}Z → {end:%F %T}Z; nothing sent", file=sys.stderr)
        return 0
    if not send(msg):
        return 1
    tmp = STATE + ".tmp"
    state["digest"] = {"last_end": int(end.timestamp())}
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, STATE)
    print(f"digest sent ({len(msg)} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
