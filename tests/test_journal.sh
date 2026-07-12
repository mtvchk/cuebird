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
echo "ALL JOURNAL TESTS PASSED"
