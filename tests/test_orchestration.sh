#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
export NOTIFYME_STATE_DIR=$(mktemp -d) MOCK_DB=$(mktemp)
export NOTIFYME_ADAPTER="$PWD/tests/mock-adapter.sh"
N="scripts/notifyme.sh"
fail() { echo "FAIL: $1"; exit 1; }
DUE=$(date -v+7d +%Y-%m-%dT09:00)

out=$(NOTIFYME_BODY="Що: перевірити гейт" NOTIFYME_PROJECT="MedSearch" \
      NOTIFYME_PROJECT_PATH="/tmp/med" NOTIFYME_RESUME_PROMPT="resume: check gate 2" \
      "$N" add "$DUE" "перевірити гейт 2") || fail "add failed"
echo "$out" | grep -q '"ok":true' || fail "add output: $out"
nmid=$(echo "$out" | sed 's/.*"id":"\([^"]*\)".*/\1/')
rid=$(echo  "$out" | sed 's/.*"reminder_id":"\([^"]*\)".*/\1/')

"$N" list active | grep -q "$nmid" || fail "active list misses new entry"
"$N" get "$nmid" | grep -q '"resume_prompt":"resume: check gate 2"' || fail "resume_prompt not journaled"

# user completes it in the Reminders app → reconcile marks done
"$PWD/tests/mock-adapter.sh" complete "$rid"
"$N" list active | grep -q "$nmid" && fail "reconcile kept completed entry active"
"$N" get "$nmid" | grep -q '"done"' || fail "reconcile did not journal done"

# cancel flow on a fresh one
out2=$("$N" add "$DUE" "друге нагадування") || fail "second add"
nmid2=$(echo "$out2" | sed 's/.*"id":"\([^"]*\)".*/\1/')
"$N" cancel "$nmid2" || fail "cancel"
"$N" get "$nmid2" | grep -q '"cancelled"' || fail "cancel not journaled"

# exit-code contract for degenerate inputs
"$N" cancel >/dev/null 2>&1; [ $? -eq 2 ] || fail "cancel without id must exit 2"
"$N" complete >/dev/null 2>&1; [ $? -eq 2 ] || fail "complete without id must exit 2"
"$N" cancel "nm_nope" >/dev/null 2>&1; [ $? -eq 3 ] || fail "cancel on missing id must exit 3"

echo "ALL ORCHESTRATION TESTS PASSED"
