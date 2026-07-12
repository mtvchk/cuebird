#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/.."
export NOTIFYME_STATE_DIR=$(mktemp -d) MOCK_DB=$(mktemp)
export NOTIFYME_ADAPTER="$PWD/tests/mock-adapter.sh"
N="scripts/notifyme.sh"
fail() { echo "FAIL: $1"; exit 1; }
expect_rc2() { "$N" "$@" >/dev/null 2>&1; [ $? -eq 2 ] || fail "expected exit 2: $N $*"; }

expect_rc2 add "not-a-date" "title"
expect_rc2 add "2026-13-01T09:00" "title"          # impossible month
expect_rc2 add "2020-01-01T09:00" "in the past"    # past date
expect_rc2 add "$(date -v+1d +%Y-%m-%dT09:00)" ""  # empty title
expect_rc2 add "$(date -v+1d +%Y-%m-%d)" "title"   # missing time part
echo "ALL VALIDATION TESTS PASSED"
