#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
export NOTIFYME_STATE_DIR=$(mktemp -d) MOCK_DB=$(mktemp)
export NOTIFYME_ADAPTER="$PWD/tests/mock-adapter.sh"
N="scripts/notifyme.sh"
fail() { echo "FAIL: $1"; exit 1; }

id1=$(NOTIFYME_PROJECT="ProjA" "$N" log declined "skip me" "2026-08-01T09:00") || fail "log declined"
NOTIFYME_PROJECT="ProjB" NOTIFYME_REOFFER_AT="2020-01-01T00:00" "$N" log deferred "ask me later" "2026-09-01T09:00" >/dev/null || fail "log deferred"

out=$("$N" list declined); echo "$out" | grep -q '"skip me"' || fail "list declined misses entry"
out=$("$N" list declined ProjB); echo "$out" | grep -q '"skip me"' && fail "project filter leaked"
out=$("$N" get "$id1"); echo "$out" | grep -q '"declined"' || fail "get by id"
out=$("$N" get "nm_nope" 2>&1); [ $? -eq 3 ] || fail "get missing should exit 3"

# past reoffer_at → due
out=$("$N" due-deferrals); echo "$out" | grep -q '"ask me later"' || fail "due-deferrals misses due entry"
# status transition: same id, new status wins
NOTIFYME_ID="$id1" "$N" log accepted "skip me" "2026-08-01T09:00" >/dev/null
out=$("$N" list declined); echo "$out" | grep -q '"skip me"' && fail "transition did not supersede"

cnt=$("$N" prune deferred) || fail "prune"
out=$("$N" list deferred); echo "$out" | grep -q '"ask me later"' && fail "prune left entry"

# exit-code contract for degenerate inputs
"$N" log "" "t" - >/dev/null 2>&1; [ $? -eq 2 ] || fail "empty status must exit 2"
"$N" log accepted "" - >/dev/null 2>&1; [ $? -eq 2 ] || fail "empty title must exit 2"
# concurrent appends must not lose entries
CONC_DIR=$(mktemp -d)
for i in $(seq 1 20); do NOTIFYME_STATE_DIR="$CONC_DIR" "$N" log declined "conc $i" - >/dev/null & done
wait
cnt=$(wc -l < "$CONC_DIR/journal.jsonl" | tr -d ' ')
[ "$cnt" -eq 20 ] || fail "concurrent appends lost entries: $cnt/20"

# realistic-payload concurrency: 4KB resume prompts must not tear
BIG=$(head -c 4096 /dev/zero | tr '\0' 'x')
CONC2=$(mktemp -d)
for i in $(seq 1 40); do NOTIFYME_STATE_DIR="$CONC2" NOTIFYME_RESUME_PROMPT="$BIG" "$N" log declined "big $i" - >/dev/null & done
wait
cnt2=$(NOTIFYME_STATE_DIR="$CONC2" "$N" list declined | wc -l | tr -d ' ')
[ "$cnt2" -eq 40 ] || fail "4KB concurrent appends torn/lost: $cnt2/40"
# malformed line must not poison the journal
echo '{broken json' >> "$CONC2/journal.jsonl"
NOTIFYME_STATE_DIR="$CONC2" "$N" list declined | wc -l | grep -q '40' || fail "malformed line poisoned list"
# degenerate args
"$N" get >/dev/null 2>&1; [ $? -eq 2 ] || fail "get without id must exit 2"
"$N" prune >/dev/null 2>&1; [ $? -eq 2 ] || fail "prune without status must exit 2"
# due-deferrals empty → zero bytes
DD=$(mktemp -d); [ -z "$(NOTIFYME_STATE_DIR="$DD" "$N" due-deferrals)" ] || fail "empty due-deferrals must print nothing"

echo "ALL JOURNAL TESTS PASSED"
