#!/bin/bash
# Real-Reminders round-trip. LOCAL-ONLY release gate — requires macOS + Reminders permission.
# Uses a throwaway project list and a temp project map; deletes both at the end.
set -uo pipefail
cd "$(dirname "$0")/.."
export CUEBIRD_STATE_DIR=$(mktemp -d)
A="scripts/adapters/apple-reminders.sh"
P="Cuebird Adapter Test"
fail() { "$A" droplist "$P" >/dev/null 2>&1; echo "FAIL: $1"; exit 1; }

out=$("$A" health) || fail "health exited nonzero: $out"
case "$out" in "ok "?*|"ok-local "?*) ;; *) fail "unexpected health output: $out";; esac
echo "PASS: health ($out)"

Y=$(date -v+1d +%Y); M=$(date -v+1d +%m); D=$(date -v+1d +%d)
rid=$("$A" add "$Y" "$M" "$D" 10 30 "Cuebird selftest" "body line 1
line 2 — created by Cuebird test" "$P") || fail "add failed"
[ -n "$rid" ] || fail "add printed empty id"
grep -q "\"$P\"" "$CUEBIRD_STATE_DIR/lists.json" || fail "project list not recorded in map"
rid2=$("$A" add "$Y" "$M" "$D" 11 00 "second, same list" "" "$P") || fail "second add failed"
[ "$(grep -c '"' "$CUEBIRD_STATE_DIR/lists.json")" -eq 1 ] || fail "second add created another list"
echo "PASS: add ($rid) reuses the project list"

[ "$("$A" status "$rid")" = "pending" ] || fail "status != pending"
[ "$("$A" status "x-apple-reminder://$rid")" = "pending" ] || fail "pre-0.2 id prefix not accepted"
"$A" list | grep -qF "$rid" || fail "list does not contain new reminder"
echo "PASS: status+list"

"$A" complete "$rid" || fail "complete failed"
[ "$("$A" status "$rid")" = "completed" ] || fail "status != completed"
"$A" delete "$rid" || fail "delete failed"
[ "$("$A" status "$rid")" = "missing" ] || fail "status != missing after delete"
"$A" delete "$rid2"
echo "PASS: complete+delete round-trip"

"$A" droplist "$P" || fail "droplist failed"
grep -q "\"$P\"" "$CUEBIRD_STATE_DIR/lists.json" && fail "droplist kept the map entry"
echo "ALL ADAPTER TESTS PASSED"
