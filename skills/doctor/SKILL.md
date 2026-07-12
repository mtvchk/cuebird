---
name: doctor
description: NotifyMe self-diagnostics. Use when reminders fail to create, the user doubts phone delivery, asks whether NotifyMe works, or wants to check for plugin updates.
---

# NotifyMe: doctor

Below, `$NOTIFYME` denotes the resolved absolute path to the CLI — it is
notation, not a shell variable: each bash command you run is its own fresh
shell, so substitute the literal path directly into every command below (or,
if you do assign a shell variable, only rely on it within one single bash
invocation, never across separate tool calls).

Resolve `$NOTIFYME` using these methods, in order — never guess beyond them:
1. If your skill invocation provides a "Base directory for this skill" (or
   equivalent), use it directly:
   `NOTIFYME=<that-base>/../../scripts/notifyme.sh`
2. Otherwise, if the environment variable `CLAUDE_PLUGIN_ROOT` is set in your
   Bash environment, use `"$CLAUDE_PLUGIN_ROOT/scripts/notifyme.sh"`.
3. Only if both of the above fail, locate the installed plugin under
   `~/.claude/plugins`:
   `ls -d ~/.claude/plugins/*/notifyme*/scripts/notifyme.sh 2>/dev/null | head -1`

The plugin root (for check 7's `plugin.json`) is `$NOTIFYME`'s grandparent
directory — derive it instead of re-resolving separately:
`PLUGIN_ROOT="$(cd "$(dirname "$(dirname "$NOTIFYME")")" && pwd)"`, then
`plugin.json` lives at `"$PLUGIN_ROOT/.claude-plugin/plugin.json"`.

None of the commands below interpolate user-supplied free text (unlike
skills/remind, skills/reminders, skills/resume) — every value is a fixed
path or CLI output you read back, not compose — so the single-quoting rule
those skills require does not apply here.

Run the seven checks below IN ORDER, then print one compact report:
`✓/✗/⚠ name — one line` each, fixes only for ✗. Don't stop early on a ✗ —
run all seven, since later checks are still informative even if an earlier
one fails.

1. **System**: `uname` is `Darwin` and `command -v osascript` succeeds.
   ✗fix: NotifyMe v1 works only on macOS.

2. **Permission**: `osascript -e 'tell application "Reminders" to count accounts'`.
   Nonzero exit, or output containing `-1743` / `Not authorized` → ✗fix:
   macOS заборонив доступ до Нагадувань. Увімкни: System Settings → Privacy
   & Security → Automation → (твій термінал/Claude) → Reminders — і повтори.
   Otherwise ✓ (report the account count printed).

3. **iCloud**: `"$NOTIFYME" health` → stdout starting `ok ` (space) means
   iCloud ✓ — report the `account/list` that follows. Stdout starting
   `ok-local ` → ⚠: «Нагадування створяться лише на цьому Mac — iPhone їх
   не побачить. Увімкни Reminders в iCloud (System Settings → Apple ID →
   iCloud).» Nonzero exit → ✗fix: exit 10 → same wording as check 2's fix;
   exit 12 or anything else → ✗fix: «Щось пішло не так із застосунком
   Нагадування. Перевір, що він встановлений і відкривається.»

4. **List**: covered by the same `health` call from check 3 — don't call it
   twice. Report ✓ with the same `account/list` (health creates the list if
   it's missing, so a ✓ here means the list exists now regardless of
   whether it existed before).

5. **Round-trip**: `"$NOTIFYME" selftest` → stdout containing `SELFTEST
   PASSED` and exit 0 → ✓. This creates, verifies, completes and deletes a
   real test reminder due tomorrow 10:30 in list «Claude Projects Test» —
   don't be alarmed if that list is momentarily visible in Reminders during
   the check. Otherwise ✗fix: surface the exact `SELFTEST FAILED: <step>`
   line from its output verbatim — that step name is the actual failure
   point (e.g. `adapter add` usually means the same permission/iCloud issue
   as checks 2–3; re-run those first).

6. **State**: the journal is a cache; Reminders is the source of truth, so
   journal issues are ✓/⚠, never a hard ✗ on their own.
   ```bash
   raw=$(grep -c . ~/.claude/notifyme/journal.jsonl 2>/dev/null); raw=${raw:-0}
   out=$("$NOTIFYME" list all); rc=$?
   ```
   Read `raw` (count of non-empty lines — historical blank lines are
   harmless and excluded) before looking at `rc`, in this order:
   - `raw` = 0 (journal never written, or empty) → ✓ regardless of `rc`.
     `list all` exits 0 on a genuinely empty journal, so `rc` should be 0
     here too — dir writability was already proven by `"$NOTIFYME"
     health`/`selftest` succeeding above.
   - `raw` > 0 and `rc` ≠ 0 → ✗fix: перевір `~/.claude/notifyme/` — я можу
     показати, що там.
   - `raw` > 0 and `rc` = 0 → ✓. Then run the direct parse-count one-liner
     below against the journal to find lines that fail to parse as JSON —
     do NOT compare `raw` against `list all`'s output, since one id can
     legitimately produce several journal lines across its lifetime
     (accepted → deferred → done/cancelled are all separate appended
     lines for the same id), so a raw-line-count vs unique-id-count
     comparison false-positives on any healthy journal containing a
     completed or cancelled reminder.
     ```bash
     /usr/bin/osascript -l JavaScript -e '
     ObjC.import("Foundation");
     function run(a){
       const s=$.NSString.stringWithContentsOfFileEncodingError(a[0],$.NSUTF8StringEncoding,null);
       if(!s||s.isNil()) return "total=0 bad=0";
       let bad=0,total=0;
       ObjC.unwrap(s).split("\n").filter(l=>l.trim()).forEach(l=>{total++;try{JSON.parse(l)}catch(e){bad++}});
       return "total="+total+" bad="+bad;
     }' "$HOME/.claude/notifyme/journal.jsonl"
     ```
     Parse `bad` from the output:
     - `bad` = 0 → ✓, no further note needed.
     - `bad` > 0 → ⚠ alongside the ✓, not a failure: «N нечитабельних
       рядків у журналі — записи пропущено; Reminders лишається джерелом
       правди» (fill in N = `bad`).

7. **Updates** (the ONLY network call in NotifyMe, run just for this check,
   never blocking any other check):
   ```bash
   local_version=$(grep -m1 '"version"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
     | sed -E 's/.*"version": *"([^"]+)".*/\1/')
   gh_out=$(curl -s --max-time 5 https://api.github.com/repos/mtvchk/notifyme/releases/latest)
   curl_rc=$?
   ```
   - `curl_rc` ≠ 0 (timeout, no network, DNS failure) → ✓ (informational,
     never a failure): «пропущено (немає мережі)».
   - `curl_rc` = 0 but the body has no `tag_name` (e.g. `"message": "Not
     Found"` — no release published yet, or the repo doesn't exist yet) →
     ✓: «пропущено (реліз ще не опубліковано)». This is the current real
     state of `mtvchk/notifyme` — expect this path, not the network-skip
     path, until the first GitHub release is published.
   - Otherwise extract `tag_name`, strip a leading `v`, and compare against
     `local_version` as plain strings (no semver math needed — GitHub's
     `/releases/latest` already returns the newest non-prerelease tag, so
     any difference from the installed version means an update exists):
     mismatch → ✓: «Доступна версія <tag> (встановлено <local_version>) —
     онови через /plugin.» Match → ✓: «Актуальна версія <local_version>.»

End with one honest summary line: all green (✓/⚠ only, no ✗) → «NotifyMe
повністю справний — нагадування долетять.» Any ✗ → name the single most
important fix first (permission/iCloud issues block everything downstream,
so lead with the earliest failing check in the 1→6 order, not check 7 —
update status never blocks delivery).
