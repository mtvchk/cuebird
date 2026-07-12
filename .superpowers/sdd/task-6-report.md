# Task 6: notifyme.sh — orchestration (add / cancel / complete / reconcile / selftest)

**Status:** Completed
**Commit:** `6d65d97` feat(cli): add/cancel/complete orchestration, reconcile-on-list, selftest
**Date:** 2026-07-12
**Test Result:** ALL ORCHESTRATION TESTS PASSED / SUITE PASSED / SELFTEST PASSED (real adapter)

---

## Summary

Replaced the staged `TODO Task 6` stub in `scripts/notifyme.sh` with real `add`,
new `cancel`/`complete` cases, a reconcile-on-list rewrite of `list`, and an inline
`selftest`. TDD approach: wrote `tests/test_orchestration.sh` from the brief first,
watched it fail against the stub, implemented, watched it pass, then ran the full
suite and the real-adapter selftest.

---

## Step-by-step

### Step 1: Read current state

Read `.superpowers/sdd/task-6-brief.md` and the current `scripts/notifyme.sh` (evolved
past the brief across Tasks 4-5: `die2`, `validate_due`, `jxa_journal` with modes
append/list/get/due/prune, and the lock-guarded `journal_append` appender). Also read
`scripts/adapters/apple-reminders.sh`, `tests/mock-adapter.sh`, `tests/run.sh`,
`tests/test_journal.sh`, `tests/test_validation.sh`, and Task 5's report/progress ledger
to confirm the established conventions (`${1:-}` + `die2` for id args, no bare `echo` on
empty output, `log`'s split-and-`journal_append` idiom for durable writes).

### Step 2: Write failing test (`tests/test_orchestration.sh`)

Copied the brief's test verbatim (it contained no antipatterns itself — only the
implementation needed adapting) and added a few extra degenerate-input assertions
consistent with the sibling test files' style (`cancel`/`complete` without an id →
exit 2; `cancel` on an unknown id → exit 3), since the brief's own test didn't exercise
the `${1:-}`+`die2` contract that the deviation notes required for the new commands.

Ran it against the stub:
```
$ ./tests/test_orchestration.sh
TODO Task 6
FAIL: add failed
```
Confirmed failure, as expected.

### Step 3: Implement

Added `osa_field`, real `add`, `cancel|complete`, rewrote `list`, added `selftest` —
see Adaptations below for every place the brief's code had to change to fit the
current codebase (and one outright bug in the brief's own snippet).

### Step 4: Run all

```
$ ./tests/run.sh
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED
```
Re-ran 3 times back-to-back, `SUITE PASSED` every time (no flakes from the
`while read` subshell + `journal_append` lock interaction).

```
$ unset NOTIFYME_ADAPTER NOTIFYME_STATE_DIR MOCK_DB NOTIFYME_LIST
$ ./scripts/notifyme.sh selftest
SELFTEST PASSED
```
Ran against the real `apple-reminders.sh` adapter (default, since `NOTIFYME_ADAPTER`
was unset) on the `Claude Projects Test` list.

### Step 5: Commit

`6d65d97 feat(cli): add/cancel/complete orchestration, reconcile-on-list, selftest`

---

## Adaptations made, and why

1. **Journal writes route through `journal_append`, not a bare `jxa_journal append`
   call.** This is the most significant deviation from the brief's literal code. In
   the current codebase (post Task 5), `jxa_journal append` never touches disk — it
   only *builds* the JSON line in JXA and returns `"<id>\n<json-line>"` to bash; the
   actual `write(2)` happens in the lock-guarded `journal_append()` bash function
   (guarding against cross-process torn writes on multi-KB lines). The brief's snippet
   (written before Task 5 existed) does:
   ```bash
   nmid=$(NOTIFYME_REMINDER_ID="$rid" jxa_journal append accepted "$title" "$due")
   ```
   which would assign `nmid` to the *entire* `"<id>\n<json>"` blob and never persist
   anything. I replaced every `jxa_journal append` call site (in `add`, `cancel`/
   `complete`, and the `list` reconcile loop) with the same split-and-persist idiom
   already used by the existing `log` case:
   ```bash
   out=$(NOTIFYME_REMINDER_ID="$rid" jxa_journal append accepted "$title" "$due") || exit 2
   nmid="${out%%$'\n'*}"; line="${out#*$'\n'}"
   journal_append "$line"
   ```

2. **`cancel`/`complete` use `${1:-}` + `die2` instead of the brief's `${1:?id}`.**
   The banned antipattern exits 1 on a missing arg (and, inside a command
   substitution, lets the outer command silently continue with empty output); the
   established pattern (already used by `get`, `due-deferrals`, `prune`) exits 2 via
   `die2`. Added `nmid="${1:-}"; [ -n "$nmid" ] || die2 "missing id"`.

3. **`list`'s reconcile loop and final output follow the "no bare echo on empty
   output" convention.** The brief's rewritten `list` case ends with an unconditional
   `echo` after `jxa_journal list "$want" "$proj"`, which would print a spurious blank
   line for empty results — inconsistent with how `due-deferrals` (Task 5) already
   handles this. Changed to capture the output and only print it (with a trailing
   newline via `printf`) when non-empty, matching `due-deferrals`'s pattern exactly.

4. **Found and fixed a real bug in the brief's `osa_field` helper.** The brief's
   version:
   ```bash
   osa_field() {
     "$OSA" -l JavaScript -e '...' - "$1" "$2"
   }
   ```
   includes a stray `-` between the `-e SCRIPT` and the args. That `-` convention is
   correct for `jxa_journal` (which passes the script via **stdin**, so `-` there
   means "read the script from stdin" and everything after it is argv). But `osa_field`
   passes the script inline via `-e`, so `osascript` has no "read from stdin" step —
   the trailing `-` is instead consumed as `argv[0]`, shifting every real argument over
   by one. Verified empirically:
   ```
   $ osascript -l JavaScript -e 'function run(a){...}' - "hello" "world"
   → a = ["-","hello","world"]        # wrong: JSON.parse("-") throws
   $ osascript -l JavaScript -e 'function run(a){...}' "hello" "world"
   → a = ["hello","world"]            # correct
   ```
   This surfaced immediately as `execution error: ... SyntaxError: JSON Parse error:
   Invalid number (-2700)` on the very first `list active` call in the new test.
   Fixed by dropping the stray `-` from `osa_field`.

5. **`tests/test_validation.sh`'s final assertion was pinned to the old stub's exit
   code.** That test's last check exercised the one code path the brief explicitly
   left broken until Task 6 ("real leap day" → "should pass validation and hit the
   Task-6 stub (exit 1)"). With `add` now real (and that test file already using the
   mock adapter via `NOTIFYME_ADAPTER`), the same input now succeeds. Updated the
   assertion to expect exit 0 and an `{"ok":true}` envelope instead of exit 1.

6. **`list`'s reconcile-loop pipeline subshell was verified, not just assumed, to
   work correctly for durable writes.** Per the task's own note, `jxa_journal list
   accepted "$proj" | while IFS= read -r entry; do ... done` runs the loop body in a
   subshell (bash pipeline semantics), so any bash variables set inside it (`rid`,
   `eid`, `st`) don't leak out — but `journal_append` calls inside the loop are
   separate child processes each independently taking the `mkdir` lock and appending
   to the on-disk journal file, so they persist correctly regardless of the subshell
   boundary. Confirmed via the test: after `mock-adapter.sh complete "$rid"` followed
   by `list active`, the *next* `get "$nmid"` call (a fresh process reading the
   journal file from scratch) sees the `done` status — proving the write from inside
   the piped subshell landed on disk before the pipeline returned control to the
   caller.

7. **`selftest` kept exactly as the brief specifies** (env-var-driven `$ADAPTER`,
   `NOTIFYME_LIST=Claude Projects Test`, inline temp-dir journal round-trip via
   `$SELF_DIR/notifyme.sh`) — no adaptation needed; it's already self-contained and
   works whether `$ADAPTER` is the mock or the real Apple Reminders adapter. Ran it in
   this session against the **real** adapter (unset `NOTIFYME_ADAPTER`) per the task
   instructions.

---

## Commands run (verbatim)

```
$ ./tests/test_orchestration.sh          # before implementation
TODO Task 6
FAIL: add failed

$ ./tests/test_orchestration.sh          # after implementation
{"ok":true}
ALL ORCHESTRATION TESTS PASSED

$ ./tests/run.sh                          # x3, no flakes
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED

$ unset NOTIFYME_ADAPTER NOTIFYME_STATE_DIR MOCK_DB NOTIFYME_LIST
$ ./scripts/notifyme.sh selftest          # real adapter, Claude Projects Test list
SELFTEST PASSED
```

---

## Self-review

- **Exit-code propagation**: `add`'s adapter call uses `rid=$("$ADAPTER" add ...) ||
  exit $?`, which correctly forwards the adapter's real exit code (10/11/12) since
  `$?` after a failed command substitution reflects the substituted command's status
  — matching the established pattern flagged in `apple-reminders.sh`'s own comment
  ("`$(...)` swallows exit codes — always guard").
- **Argument safety**: all JSON field extraction goes through `osa_field`, which
  receives the JSON blob and field name as `argv` entries to `osascript`, never via
  shell string interpolation into the JXA source — so titles/resume-prompts containing
  quotes, Cyrillic text, or other JSON-special characters (exercised by the test with
  `перевірити гейт 2` / `Що: перевірити гейт`) can't break out of the script or corrupt
  parsing.
- **Reconcile correctness**: only entries with `status === 'accepted'` (last state) are
  candidates for reconciliation; entries with no `reminder_id` are skipped (`[ -n "$rid"
  ] || continue`) so log-only entries (declined/deferred with no adapter binding) are
  never touched. Adapter status-check failures fall back to `pending` (no false
  cancel/done), so a permission blip or JSON adapter error can't cause events to be
  wrongly marked done or cancelled.
- **Idempotency**: since `jxa_journal list accepted ...` only returns the current last
  state, a `list active` call after reconciliation already ran (and superseded the
  entry) won't re-emit it for reconciliation — no double-transition risk on repeated
  `list` calls.
- **Consistency with Task 5's contract**: field-set/omission behavior (`Object.keys(e
  ).forEach(k => { if (e[k] === '') delete e[k]; })`) is unchanged and untouched by this
  task; `cancel`/`complete` deliberately drop `reminder_id` on the terminal entry (by
  not passing `NOTIFYME_REMINDER_ID` when appending `cancelled`/`done`), matching the
  brief's own design — terminal entries don't need to remain reconcile-candidates.
- **Known pre-existing risk, not introduced by this task**: if `jxa_journal append`
  fails *after* the adapter has already created (or mutated) the underlying reminder —
  e.g., an osascript hiccup writing the JSON line — the command exits 2 with no journal
  entry recorded, leaving an orphan reminder. This exact risk already existed in the
  `log` case since Task 5 and is structurally identical here; not introduced or
  worsened by this task, and out of the brief's scope, but worth flagging for a future
  hardening pass (e.g., a compensating delete on journal-write failure).

## Concerns to flag

- The `osa_field` bug (item 4 above) was in the brief itself, not something introduced
  by adapting to codebase drift — worth a note for whoever reviews future briefs that
  reuse the `-e` + positional-args osascript invocation style, since it's easy to
  copy the stdin-script `-` convention by mistake.
- The orphan-reminder risk in item "Known pre-existing risk" above (shared with the
  Task 5 `log` case) is unresolved; flagging for the final release-gate review rather
  than fixing here since it's out of this task's stated scope and touches Task 5's
  already-reviewed code.

---

## Fix round 1

Addressed 5 review findings against this task's implementation.

### Changes

1. **`cancel`/`complete` now status-first, not fire-and-forget (Medium).** Previously
   `"$ADAPTER" delete/complete "$rid" || true` swallowed genuine adapter failures
   (e.g. permission revoked) and always journaled the terminal state regardless —
   masking real errors and permanently desyncing the journal from Reminders (since
   reconcile never re-examines terminal entries). Now checks `"$ADAPTER" status "$rid"`
   first: if already `missing`, nothing to do in Reminders (journaling the terminal
   state below *is* the reconcile); otherwise the delete/complete call must succeed
   or the command exits with the adapter's real exit code (`|| exit $?`) and does
   **not** journal a terminal state on failure.

2. **Reconcile loop's two `jxa_journal append` calls guarded (Medium).** In `list`'s
   reconcile branch (`completed`/`missing` cases), `out=$(jxa_journal append ...)` was
   unguarded — a JXA failure would silently `journal_append ""`, appending a blank
   line to the journal and losing the error. Both branches now do
   `... || continue`, then only call `journal_append "$line"` when `$line` is
   non-empty, preserving the existing id/json split idiom.

3. **`journal_append`'s return status is now the write's, not `rmdir`'s (Low).**
   Previously `return` (implicit) reflected `rmdir "$lockdir"`'s exit status, so a
   failed `printf >> "$JOURNAL"` (e.g. disk full) was invisible to callers. Now
   captures `rc=$?` right after the `printf`, always releases the lock, then
   `return $rc`. Wired the check into `add`: after a successful adapter create, if
   `journal_append "$line"` fails, prints `journal write failed (reminder created:
   $rid)` to stderr and exits 12 (documents the orphan-reminder case instead of
   silently losing it).

4. **New reconcile test: missing → cancelled (Low).** Added a third `add` in
   `tests/test_orchestration.sh` followed by `tests/mock-adapter.sh delete "$rid3"`
   directly (simulating the user deleting the reminder in the Reminders app, not via
   `notifyme cancel`), then asserts `list active` no longer contains the id and
   `get` shows `"cancelled"` — exercising the `missing` branch of the reconcile loop,
   which previously had no direct test coverage.

5. **`add`'s success envelope built via JXA instead of hand-spliced `printf` (Low).**
   Replaced `printf '{"ok":true,"id":"%s","reminder_id":"%s"}\n' "$nmid" "$rid"` with
   `"$OSA" -l JavaScript -e 'function run(a){return JSON.stringify({ok:true,id:a[0],reminder_id:a[1]})}' "$nmid" "$rid"`
   for consistency with the rest of the codebase's JSON construction (and to avoid
   any future hand-spliced-JSON bug class). No stray `-` before the args (this is
   the `-e` form, not the stdin-script form `jxa_journal` uses — see the Task 6
   `osa_field` bug note above for why that distinction matters). Verified the output
   shape is unchanged (`{"ok":true,"id":...,"reminder_id":...}`, same key order) so
   existing tests still pass unmodified.

### Verification

```
$ bash -n scripts/notifyme.sh
(no output — syntax OK)

$ ./tests/run.sh
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED

$ ./tests/run.sh          # 2nd run, no flakes
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED

$ unset NOTIFYME_ADAPTER NOTIFYME_STATE_DIR MOCK_DB NOTIFYME_LIST
$ ./scripts/notifyme.sh selftest      # real adapter, Claude Projects Test list
SELFTEST PASSED
```

### Files touched

- `scripts/notifyme.sh` — findings 1, 2, 3, 5
- `tests/test_orchestration.sh` — finding 4

---

## Re-review after fix round 1

**Verification performed:** read full diff `review-acaa255..a78351c.diff`, current
`scripts/notifyme.sh`, `tests/test_orchestration.sh`, `tests/mock-adapter.sh`,
`scripts/adapters/apple-reminders.sh`; ran `bash -n scripts/notifyme.sh` (clean);
ran `./tests/run.sh` three times back-to-back (no flakes, `SUITE PASSED` every time).

### Prior findings — verified

- **M1 (status-first cancel/complete)**: confirmed. `st=$("$ADAPTER" status "$rid" ...) ; if [ "$st" != "missing" ]; then ... || exit $?; fi` now propagates the adapter's real exit code on genuine delete/complete failure and no longer reaches the journaling lines on that path. Fixed as described, **but see new finding below** — the fallback used when the status check itself fails is unsafe.
- **M2 (reconcile appends unguarded)**: confirmed. Both `completed)` and `missing)` branches in `list`'s reconcile loop now do `out=$(...) || continue` followed by `[ -n "$line" ] && journal_append "$line"`. Correct.
- **L3 (`journal_append` return status)**: confirmed correct, and verified the specific mechanic the fix relies on: `local rc=$?` captures `$?` from the parameter expansion that happens *before* the `local` builtin runs, so it is not clobbered by `local`'s own exit status (this is not the classic `local x=$(cmd)` pitfall — there's no command substitution on this right-hand side, just a scalar). Empirically verified with a throwaway test (`local rc=$?` after `( exit 7 )` correctly captured `7`). `rmdir` runs unconditionally afterward and does not affect the returned `$rc`. Wired correctly into `add`'s new exit-12 branch.
- **L4 (missing→cancelled reconcile test)**: confirmed present (`tests/test_orchestration.sh` lines 31–37) and it passes. However, note under new findings: only the *reconcile* path is now tested for `missing`; the explicit `complete` command's happy path (as opposed to `cancel`, which is directly tested) still has no direct test.
- **L5 (JXA envelope for `add`'s success output)**: confirmed correct. `"$OSA" -l JavaScript -e '...' "$nmid" "$rid"` uses the `-e` inline-script form with **no** leading `-`, which is the correct convention (the stray-`-` bug class from the original `osa_field` only applies when the script is passed via stdin with `-` as a placeholder arg0). `a[0]`/`a[1]` correctly map to `nmid`/`rid`.

### New issues found

**1. (Medium) `cancel`/`complete`'s status-first fallback conflates "status check failed" with "confirmed missing," silently skipping the real action.**
`scripts/notifyme.sh` line ~141:
```bash
st=$("$ADAPTER" status "$rid" 2>/dev/null) || st="missing"
```
If the adapter's `status` subcommand itself fails (nonzero exit — e.g. `apple-reminders.sh`'s own `run_osa` mapping a transient `-600` "app unavailable" failure to exit 12, or any other error path), this line treats that failure identically to a confirmed "the reminder is gone." Because `[ "$st" != "missing" ]` gates the delete/complete call, this fallback causes the code to **skip the real adapter action entirely** and fall straight through to journaling the terminal state (`cancelled`/`done`) — permanently marking the entry terminal (only `accepted` entries are ever reconciled again) even though the underlying reminder may still exist untouched in Reminders. No error is surfaced to the caller; the journal silently and permanently diverges from reality. This directly undermines M1's stated intent ("propagate errors ... journal only on success-or-missing" — a status-check failure is neither).

Compare this to the **safe** fallback already used a few lines below, in `list`'s reconcile loop, for the *same* `"$ADAPTER" status` call:
```bash
st=$("$ADAPTER" status "$rid" 2>/dev/null || echo pending)
```
There, a status-check failure defaults to `pending` (i.e. "unknown → assume still active, don't touch it"), which is the safe direction — it can never wrongly finalize an entry. `cancel`/`complete` should use the same safe fallback (or better: treat a genuine status-check failure as a hard error via `exit $?`/exit 12, distinct from "missing"), not silently reinterpret it as "nothing to do, journal it done."

**2. (Medium) `cancel`/`complete`'s final `journal_append` call is unguarded, unlike `add`'s.**
`scripts/notifyme.sh` lines ~148–151:
```bash
newst=$([ "$cmd" = cancel ] && echo cancelled || echo done)
out=$(NOTIFYME_ID="$nmid" jxa_journal append "$newst" "$(osa_field "$entry" title)" "$(osa_field "$entry" due)") || exit 2
journal_append "${out#*$'\n'}"
echo '{"ok":true}'
```
`journal_append` here is called with no `||` guard at all — its (now-meaningful, post-L3) return status is discarded. If the disk write fails (lock-steal edge case, disk full, etc.) *after* the adapter-side delete/complete already succeeded (or was skipped because the item was confirmed missing), the command still prints `{"ok":true}` and exits 0, even though the terminal state was never persisted. The journal keeps showing `accepted` forever with no error raised — exactly the failure mode L3 was introduced to make detectable, and exactly the pattern `add` correctly applies two cases above it (`journal_append "$line" || { echo "..." >&2; exit 12; }`). This looks like the L3 fix was wired into `add` but not into `cancel`/`complete`, despite both being the same "adapter action succeeded, now persist the terminal state" shape. (Note: `log`'s equivalent call is also unguarded, but that's pre-existing from Task 5 and out of this diff's scope — still, it shows the inconsistency is systemic, not a one-off.)

**3. (Low) `add`'s `jxa_journal append` failure path gives no orphan-reminder warning, unlike the `journal_append` failure path two lines later.**
```bash
rid=$("$ADAPTER" add "$y" "$m" "$d" "$H" "$M" "$title" "${NOTIFYME_BODY:-}") || exit $?
out=$(NOTIFYME_REMINDER_ID="$rid" jxa_journal append accepted "$title" "$due") || exit 2
...
journal_append "$line" || { echo "journal write failed (reminder created: $rid)" >&2; exit 12; }
```
By the time `jxa_journal append` runs, the adapter has already created a real reminder (`$rid`). If this JXA call fails (unlikely — it's pure JS with no journal I/O — but not impossible: osascript unavailable, JXA runtime error), the command exits 2 silently, with no message that a live orphaned reminder now exists with zero journal trace — inconsistent with the very next failure branch, which does print `"journal write failed (reminder created: $rid)"` for the analogous risk. Low severity/likelihood, but worth aligning for consistency and debuggability.

**4. (Low, theoretical — ⚠️ cannot verify without live timing control) TOCTOU race window in `cancel`/`complete` between the status read and the delete/complete call.**
Two separate `osascript` invocations (`status`, then `delete`/`complete`) are not atomic. If the user completes the reminder in the Reminders app in the narrow window between them, `cancel`'s subsequent `delete` still succeeds (delete doesn't care about completed state) and the journal records `cancelled`, silently discarding the true `done` transition with no error and no way to reconcile it later (terminal, never re-examined). Conversely, if the user deletes the reminder in the window between `status` and `complete`, the `complete` call now fails hard (`|| exit $?`, likely exit 12) where the old `|| true` code silently succeeded — this is arguably an *improvement* in honesty but does mean a purely benign, self-healing race (the next `list active` reconcile would have caught the `missing` state anyway) now surfaces as a hard error to the caller. This is inherent to check-then-act without an atomic adapter primitive, and the window is small (single local AppleScript round-trip), but it wasn't discussed in the fix notes and is worth documenting as an accepted risk (the codebase already documents comparable narrow races elsewhere, e.g. the lock-steal comment and prune's "acceptable race window" note).

**5. (Low, test coverage) The explicit `complete` command's happy path is never directly tested.**
`tests/test_orchestration.sh` directly tests `cancel <id>` (line 28) but `complete` is only ever exercised indirectly via the `list active` reconcile path (mock-adapter completed out-of-band), never via `"$N" complete <id>` itself. Since `complete` shares the `cancel|complete)` case body but takes the *other* branch of `"$ADAPTER" complete` vs `"$ADAPTER" delete`, and since finding 1 above lives in this exact shared block, a direct `"$N" complete <id>` assertion would have exercised — and could have caught — issues in that branch specifically.

### Spec compliance

✅ — `add`/`cancel`/`complete`/`list active` reconcile/`selftest` all match the interfaces described in the Task 6 brief and spec §8.3/§12 exit-code contract (10/11/12 passthrough, 2 for validation, 3 for not-found). All prior review findings (M1, M2, L3, L4, L5) are substantively fixed as claimed, with one caveat on M1 (finding 1 above, a related-but-distinct gap in the same fallback logic).

### Issues by severity

- **Medium**: finding 1 (unsafe `missing`-on-status-failure fallback in cancel/complete), finding 2 (unguarded final `journal_append` in cancel/complete)
- **Low**: finding 3 (no orphan warning on `add`'s jxa_journal-append failure), finding 4 (TOCTOU race, theoretical), finding 5 (no direct `complete` test)

### ⚠️ Cannot verify

- Finding 4 (TOCTOU race) is reasoned from code inspection, not exercised — reproducing it requires injecting a timed external mutation between two `osascript` calls, not practical in the current test harness.
- Whether `apple-reminders.sh`'s `status` subcommand can actually return non-zero for reasons other than a caught-and-returned `"missing"` string (e.g. a `-600` app-unavailable error escaping its inner `try`/`on error`) was reasoned from the AppleScript structure, not confirmed by forcing that condition against the real Reminders app — the asymmetry with `list`'s safe `|| echo pending` fallback stands regardless of how often the failure path triggers.

### Task quality: Needs fixes

Fix round 1 correctly and verifiably addressed all five prior findings, and the "status-first" direction for M1 was the right call. But it introduced (or left unclosed) two Medium-severity gaps in the exact same code path it touched: an unsafe failure fallback in the new status check (finding 1), and a missing failure guard on the new final `journal_append` call that the sibling `add` case already has (finding 2). Both are silent-desync risks in the same spirit as M1's original concern and should be closed before this task is signed off.

---

## Fix round 2

Addressed 5 review findings from the re-review after fix round 1.

### Changes

1. **`cancel`/`complete`'s status-check failure now propagates instead of being
   conflated with "confirmed missing" (Medium).**
   ```bash
   st=$("$ADAPTER" status "$rid" 2>/dev/null) || exit $?
   ```
   replaces `|| st="missing"`. The adapter's `status` subcommand exits 0 even when the
   reminder is genuinely gone (it prints the string `missing`); a nonzero exit means the
   status check itself failed (permission/app error), which must abort the command
   rather than silently being treated as "gone, so journal the terminal state." This
   closes the gap left by fix round 1's M1 fix, which fixed the delete/complete branch
   but left this exact same conflation on the status read one line above it.

2. **`cancel`/`complete`'s final `journal_append` is now guarded, matching `add`
   (Medium).**
   ```bash
   journal_append "${out#*$'\n'}" \
     || { echo "journal write failed — стан у Reminders змінено, але не зафіксовано; повтори команду" >&2; exit 12; }
   ```
   Previously this call's return status was discarded, so a disk-write failure after
   the adapter-side delete/complete had already succeeded (or was correctly skipped as
   confirmed-missing) still printed `{"ok":true}` and exited 0 — the terminal state was
   never actually persisted, with no error surfaced. The guard message is phrased for
   this call site specifically (the adapter action **has** already succeeded by this
   point, unlike `add`'s message which flags an orphan reminder from a create that
   can't be undone).

3. **`add`'s `jxa_journal append` failure path now warns about the orphan reminder,
   like the `journal_append` failure path two lines later (Low).**
   ```bash
   out=$(NOTIFYME_REMINDER_ID="$rid" jxa_journal append accepted "$title" "$due") \
     || { echo "journal build failed (reminder created: $rid)" >&2; exit 12; }
   ```
   replaces the bare `|| exit 2`. By this point the adapter has already created a real
   reminder (`$rid`); exiting silently with code 2 (the validation-error code) both hid
   the orphan and mislabeled an internal failure as a bad-input error. Now exits 12
   (internal failure, input was valid) with the same orphan-warning shape as the
   sibling `journal_append` guard right below it.

4. **TOCTOU comment added, no logic change (Low, adjudicated accepted).**
   ```bash
   # TOCTOU between status and delete/complete is accepted: single-user tool,
   # window is ms; worst case reconcile self-heals on next list.
   ```
   placed directly above the status-check line in `cancel`/`complete`, documenting the
   re-review's finding 4 (the narrow race between reading status and acting on it) as a
   deliberately accepted risk, consistent with how the codebase already documents
   comparable narrow races elsewhere (the lock-steal comment, `prune`'s "acceptable race
   window" note).

5. **New direct `complete` happy-path test (Low, test coverage).**
   `tests/test_orchestration.sh` previously only exercised `complete` indirectly via the
   `list active` reconcile path; `cancel` had a direct test but `complete` did not, even
   though the two share the same `cancel|complete)` case body and finding 1 above lived
   in exactly that shared block. Added a fourth `add` → `"$N" complete "$nmid4"` → assert
   exit 0 + `{"ok":true}` → assert `get` shows `"done"` → assert the mock adapter's own
   `status "$rid4"` reads `completed`, giving direct coverage of the `complete` branch
   end to end (CLI exit code, journal state, and adapter-side effect).

### Verification

```
$ bash -n scripts/notifyme.sh && bash -n tests/test_orchestration.sh
(no output — syntax OK)

$ ./tests/run.sh
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED

$ ./tests/run.sh          # 2nd run, no flakes
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED

$ unset NOTIFYME_ADAPTER NOTIFYME_STATE_DIR MOCK_DB NOTIFYME_LIST
$ ./scripts/notifyme.sh selftest      # real adapter, Claude Projects Test list
SELFTEST PASSED
```

### Files touched

- `scripts/notifyme.sh` — findings 1, 2, 3, 4
- `tests/test_orchestration.sh` — finding 5

---

## Fix round 3

Addressed 2 low-severity findings in `list` reconcile loop and error messaging.

### Changes

1. **`list` reconcile loop's two `journal_append` calls now guard against write
   failure with a warning instead of silent drop (Medium).**
   Lines ~180 and ~185 in the `completed` and `missing` branches:
   ```bash
   [ -n "$line" ] && { journal_append "$line" || echo "warning: reconcile journal write failed (will retry on next list)" >&2; }
   ```
   Previously the two `[ -n "$line" ] && journal_append "$line"` calls in the reconcile
   loop discarded the `journal_append` return status, so a disk write failure would
   silently drop the reconciliation entry without surfacing any error. Since the
   reconcile is self-healing (the next `list active` call retries), the right guard is a
   WARNING to stderr rather than an abort — the entry will be re-examined and reconciled
   on the next list invocation. This pattern is consistent with reconcile's design: it
   runs on every `list`, so transient write failures (e.g. disk full, lock-steal edge
   case) are expected to clear by the next run.

2. **Error message on line ~154 now English-only (Low).**
   Replaced mixed-language message:
   ```bash
   "journal write failed — стан у Reminders змінено, але не зафіксовано; повтори команду"
   ```
   with:
   ```bash
   "journal write failed — Reminders state WAS changed but not recorded; re-run the command"
   ```
   All code/error strings in this repo are English (skills translate for users);
   non-English error strings create maintenance burden and inconsistency. This message
   now matches the codebase's established English-only convention.

### Verification

```
$ bash -n scripts/notifyme.sh
(no output — syntax OK)

$ ./tests/run.sh
== test_validation.sh
ALL VALIDATION TESTS PASSED
== test_journal.sh
ALL JOURNAL TESTS PASSED
== test_orchestration.sh
{"ok":true}
ALL ORCHESTRATION TESTS PASSED
SUITE PASSED
```

### Files touched

- `scripts/notifyme.sh` — findings 1, 2
