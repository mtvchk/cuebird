#!/bin/bash
# NotifyMe delivery adapter: Apple Reminders. ALL AppleScript lives here.
# Contract (spec §12): add | list | status | complete | delete | health
set -uo pipefail
LIST="${NOTIFYME_LIST:-Claude Projects}"
OSA=/usr/bin/osascript

# Exit codes: 10 permission denied, 11 verify failed (used by add, Task 3), 12 other failure
run_osa() { # stdin: applescript; args: argv for the script
  local out
  out=$("$OSA" - "$@" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then
    case "$out" in
      *-1743*|*"Not authorized"*) echo "permission" >&2; exit 10 ;;
      *-600*) echo "reminders-app-unavailable" >&2; exit 12 ;;
      *) echo "$out" >&2; exit 12 ;;
    esac
  fi
  printf '%s' "$out"
}

resolve_account() { # prints "<flag>\t<account>": flag=icloud|local
  run_osa <<'EOF'
on run argv
  tell application "Reminders"
    set accNames to name of every account
    if accNames contains "iCloud" then return "icloud" & tab & "iCloud"
    return "local" & tab & (item 1 of accNames)
  end tell
end run
EOF
}

ensure_list() { # $1 account
  run_osa "$1" "$LIST" <<'EOF' >/dev/null
on run argv
  tell application "Reminders"
    tell account (item 1 of argv)
      if not (exists list (item 2 of argv)) then
        make new list with properties {name:(item 2 of argv)}
      end if
    end tell
  end tell
end run
EOF
}

cmd="${1:-}"; shift || true
case "$cmd" in
  health)
    acct_info=$(resolve_account) || exit $?
    flag="${acct_info%%$'\t'*}"; acct="${acct_info#*$'\t'}"
    ensure_list "$acct"
    if [ "$flag" = "icloud" ]; then echo "ok $acct/$LIST"; else echo "ok-local $acct/$LIST"; fi
    ;;
  *)
    echo "unknown command: $cmd" >&2; exit 2 ;;
esac
