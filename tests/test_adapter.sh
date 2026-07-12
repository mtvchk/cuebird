#!/bin/bash
# Real-Reminders round-trip. LOCAL-ONLY release gate — requires macOS + Reminders permission.
set -uo pipefail
cd "$(dirname "$0")/.."
export NOTIFYME_LIST="Claude Projects Test"
A="scripts/adapters/apple-reminders.sh"
fail() { echo "FAIL: $1"; exit 1; }

out=$("$A" health) || fail "health exited nonzero: $out"
case "$out" in ok\ */"$NOTIFYME_LIST"|ok-local\ */"$NOTIFYME_LIST") ;; *) fail "unexpected health output: $out";; esac
echo "PASS: health"
