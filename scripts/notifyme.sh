#!/bin/bash
# NotifyMe CLI façade. Skills call this and never the adapter directly.
# Commands: add | log | list | get | cancel | complete | due-deferrals | prune | health | selftest
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${NOTIFYME_STATE_DIR:-$HOME/.claude/notifyme}"
ADAPTER="${NOTIFYME_ADAPTER:-$SELF_DIR/adapters/apple-reminders.sh}"
JOURNAL="$STATE_DIR/journal.jsonl"
OSA=/usr/bin/osascript

mkdir -p "$STATE_DIR"
[ -f "$STATE_DIR/config.json" ] || printf '{ "list_name": "Claude Projects", "default_hour": 9 }\n' > "$STATE_DIR/config.json"
touch "$JOURNAL"

die2() { echo "$1" >&2; exit 2; }

validate_due() { # $1: YYYY-MM-DDTHH:MM (local); dies with exit 2, else echoes y m d H M
  [[ "$1" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2})$ ]] \
    || die2 "invalid datetime: '$1' (need YYYY-MM-DDTHH:MM, local time)"
  local y=${BASH_REMATCH[1]} m=${BASH_REMATCH[2]} d=${BASH_REMATCH[3]} H=${BASH_REMATCH[4]} M=${BASH_REMATCH[5]}
  local epoch
  epoch=$(date -j -f "%Y-%m-%dT%H:%M" "$1" +%s 2>/dev/null) || die2 "impossible date: '$1'"
  [ "$epoch" -gt "$(date +%s)" ] || die2 "date is in the past: '$1'"
  echo "$y $m $d $H $M"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  add)
    due="${1:-}"; title="${2:-}"
    [ -n "$title" ] || die2 "empty title"
    comps=$(validate_due "$due") || exit 2
    read -r y m d H M <<< "$comps"
    echo "TODO Task 6" >&2; exit 1
    ;;
  health)
    "$ADAPTER" health
    ;;
  *) die2 "unknown command: $cmd" ;;
esac
