#!/bin/bash
# Project names must match what Claude Code shows, and every worktree must map to its main project.
set -uo pipefail
cd "$(dirname "$0")/.."
export CUEBIRD_STATE_DIR=$(mktemp -d) CUEBIRD_ADAPTER="$PWD/tests/mock-adapter.sh" MOCK_DB=$(mktemp)
unset CUEBIRD_PROJECT
N="$PWD/scripts/cuebird.sh"
fail() { echo "FAIL: $1"; exit 1; }
T=$(mktemp -d)

git init -q "$T/Some Folder" && git -C "$T/Some Folder" remote add origin git@github.com:someone/repo-name.git
[ "$("$N" project "$T/Some Folder")" = "repo-name" ] || fail "ssh remote → repo name"
git -C "$T/Some Folder" remote set-url origin https://github.com/someone/other.git
[ "$("$N" project "$T/Some Folder")" = "other" ] || fail "https remote → repo name"

git init -q "$T/main-proj" && git -C "$T/main-proj" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$T/main-proj" worktree add -q "$T/main-proj--wt-x" 2>/dev/null
[ "$("$N" project "$T/main-proj--wt-x")" = "main-proj" ] || fail "worktree → main checkout name"

mkdir "$T/plain"
[ "$("$N" project "$T/plain")" = "plain" ] || fail "non-git dir → basename"

# add without CUEBIRD_PROJECT derives it from CUEBIRD_PROJECT_PATH and journals it
out=$(CUEBIRD_PROJECT_PATH="$T/main-proj--wt-x" "$N" add "$(date -v+7d +%Y-%m-%dT09:00)" "t") || fail "add"
id=$(echo "$out" | sed 's/.*"id":"\([^"]*\)".*/\1/')
"$N" get "$id" | grep -q '"project":"main-proj"' || fail "derived project not journaled"
echo "ALL PROJECT TESTS PASSED"
