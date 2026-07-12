#!/bin/bash
# NotifyMe SessionStart: one sentence of awareness + any due deferred offers.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "NotifyMe is installed: when a concrete future deadline or checkpoint emerges — from the user's words or from your own analysis and plans — offer once to set a phone reminder (skill notifyme:remind). If the user mentions a reminder that fired, use skill notifyme:resume."
"$DIR/../scripts/notifyme.sh" due-deferrals 2>/dev/null | while IFS= read -r line; do
  [ -n "$line" ] && echo "NotifyMe: a previously deferred reminder offer is now due — re-offer it once at a natural pause: $line"
done
exit 0
