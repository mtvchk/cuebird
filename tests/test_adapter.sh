#!/bin/bash
# Real-Reminders round-trip. LOCAL-ONLY release gate — requires macOS + Reminders permission.
set -uo pipefail
cd "$(dirname "$0")/.."
export NOTIFYME_LIST="Claude Projects Test"
A="scripts/adapters/apple-reminders.sh"
fail() { echo "FAIL: $1"; exit 1; }

out=$("$A" health) || fail "health exited nonzero: $out"
case "$out" in ok\ */"$NOTIFYME_LIST"|ok-local\ */"$NOTIFYME_LIST") ;; *) fail "unexpected health output: $out";; esac
acct_part="${out#ok }"; acct_part="${acct_part#ok-local }"; acct_part="${acct_part%%/*}"
[ -n "$acct_part" ] || fail "empty account segment in health output: $out"
echo "PASS: health"
