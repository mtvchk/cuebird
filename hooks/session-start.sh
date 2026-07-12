#!/bin/bash
# Cuebird SessionStart: one sentence of awareness + any due deferred offers.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Cuebird is installed: when a concrete future deadline, checkpoint, or dateless waiting condition (estimate its timeframe yourself) emerges — from the user's words or your own analysis and plans — offer once to set a phone reminder (skill cuebird:remind). If the user mentions a reminder that fired, use skill cuebird:resume."
"$DIR/../scripts/cuebird.sh" due-deferrals 2>/dev/null | while IFS= read -r line; do
  [ -n "$line" ] && echo "Cuebird: a previously deferred reminder offer is now due — re-offer it once at a natural pause: $line"
done
exit 0
