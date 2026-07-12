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

jxa_journal() { # $1: mode (append|list|get|due|prune), then mode args; env passes fields
  "$OSA" -l JavaScript - "$JOURNAL" "$@" <<'EOF'
ObjC.import('Foundation');
function readLines(p) {
  const s = $.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null);
  if (!s || s.isNil && s.isNil()) return [];
  return ObjC.unwrap(s).split('\n').filter(l => l.trim()).map(l => JSON.parse(l));
}
function lastState(entries) {
  const m = {};
  entries.forEach(e => { m[e.id] = e; });
  return Object.values(m);
}
function env(k) { const v = $.NSProcessInfo.processInfo.environment.objectForKey(k); return v.isNil() ? "" : ObjC.unwrap(v); }
function run(argv) {
  const path = argv[0], mode = argv[1];
  if (mode === 'append') {
    const e = {
      id: env('NOTIFYME_ID') || 'nm_' + Date.now() + '_' + Math.floor(Math.random()*1e6),
      status: argv[2], title: argv[3], due: argv[4] === '-' ? '' : argv[4],
      project: env('NOTIFYME_PROJECT'), project_path: env('NOTIFYME_PROJECT_PATH'),
      context: env('NOTIFYME_CONTEXT'), resume_prompt: env('NOTIFYME_RESUME_PROMPT'),
      reminder_id: env('NOTIFYME_REMINDER_ID'), reoffer_at: env('NOTIFYME_REOFFER_AT'),
      created_at: new Date().toISOString()
    };
    Object.keys(e).forEach(k => { if (e[k] === '') delete e[k]; });
    const existing = readLines(path);
    existing.push(e);
    const body = existing.map(l => JSON.stringify(l)).join('\n') + (existing.length ? '\n' : '');
    $.NSString.alloc.initWithUTF8String(body).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
    return e.id;
  }
  const states = lastState(readLines(path));
  if (mode === 'list') {
    const status = argv[2] || 'all', project = argv[3] || '';
    return states
      .filter(e => status === 'all' || e.status === status)
      .filter(e => !project || e.project === project)
      .map(e => JSON.stringify(e)).join('\n');
  }
  if (mode === 'get') {
    const hit = states.find(e => e.id === argv[2]);
    if (!hit) { return '__NOTFOUND__'; }
    return JSON.stringify(hit);
  }
  if (mode === 'due') {
    const now = new Date();
    // reoffer_at is local naive YYYY-MM-DDTHH:MM — compare as local
    return states.filter(e => e.status === 'deferred' && e.reoffer_at &&
      new Date(e.reoffer_at.replace('T', ' ') + ':00') <= now)
      .map(e => JSON.stringify(e)).join('\n');
  }
  if (mode === 'prune') {
    const drop = new Set(states.filter(e => e.status === argv[2]).map(e => e.id));
    const kept = readLines(path).filter(e => !drop.has(e.id));
    const body = kept.map(e => JSON.stringify(e)).join('\n') + (kept.length ? '\n' : '');
    $.NSString.alloc.initWithUTF8String(body).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
    return String(drop.size);
  }
  return '';
}
EOF
}

validate_due() { # $1: YYYY-MM-DDTHH:MM (local); dies with exit 2, else echoes y m d H M
  [[ "$1" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2})$ ]] \
    || die2 "invalid datetime: '$1' (need YYYY-MM-DDTHH:MM, local time)"
  local y=${BASH_REMATCH[1]} m=${BASH_REMATCH[2]} d=${BASH_REMATCH[3]} H=${BASH_REMATCH[4]} M=${BASH_REMATCH[5]}
  local epoch
  epoch=$(date -j -f "%Y-%m-%dT%H:%M" "$1" +%s 2>/dev/null) || die2 "impossible date: '$1'"
  local roundtrip
  roundtrip=$(date -j -f "%Y-%m-%dT%H:%M" "$1" "+%Y-%m-%dT%H:%M" 2>/dev/null) || die2 "impossible date: '$1'"
  [ "$roundtrip" = "$1" ] || die2 "impossible date: '$1' (did you mean $roundtrip?)"
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
  log) # <status> <title> <due-or->
    st="${1:?status}"; ti="${2:?title}"; du="${3:--}"
    case "$st" in accepted|declined|deferred|cancelled|done) ;; *) die2 "bad status: $st";; esac
    [ -n "$ti" ] || die2 "empty title"
    jxa_journal append "$st" "$ti" "$du"
    echo
    ;;
  list)
    jxa_journal list "${1:-all}" "${2:-}"
    echo
    ;;
  get)
    out=$(jxa_journal get "${1:?id}")
    [ "$out" = "__NOTFOUND__" ] && exit 3
    echo "$out"
    ;;
  due-deferrals)
    jxa_journal due
    echo
    ;;
  prune)
    jxa_journal prune "${1:?status}"
    echo
    ;;
  health)
    "$ADAPTER" health
    ;;
  *) die2 "unknown command: $cmd" ;;
esac
