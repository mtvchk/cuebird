# Changelog

## [0.2.0] — 2026-10-12

- **One Reminders list per project**, named like the project in Claude Code:
  the `origin` repo name, else the main checkout folder, so every worktree
  lands in its main project. The name is derived by the CLI
  (`cuebird.sh project [path]`), never composed by the model, so duplicate
  checks and list names can't drift.
- **Adapter moved from AppleScript to EventKit.** AppleScript cannot see
  lists inside a list group at all, so grouping the old list by hand
  silently broke Cuebird (it recreated the list). EventKit sees them; group
  your project lists however you like. Reminder ids are unchanged, so
  existing journal entries keep working.
- Permission prompt is now Privacy & Security → Reminders (was Automation).
- `cuebird:doctor` check 4 now lists your project lists; the selftest uses a
  throwaway list it deletes afterwards.
- Upgrading: reminders already in the old single «Claude Projects» list keep
  working where they are — leave them there and delete the list once it's
  empty. Don't drag them into a project list: moving a synced reminder to
  another list gives it a new id, and Cuebird then reads it as removed.
- Fixed: repository links pointed at the old `itsmynamee` GitHub name, which
  now belongs to someone else.

## [0.1.0] — 2026-07-12

Initial public release.

- Four skills: `cuebird:remind` (proactive offer + create), `cuebird:reminders`
  (the decision journal — view, cancel, re-enable, defer, clean history),
  `cuebird:resume` (continue from a fired reminder via `«нагадування: <key>»`),
  `cuebird:doctor` (seven-point self-diagnostics, the seventh being an on-demand update check).
- `SessionStart` hook: injects one sentence of reminder-offering awareness per
  session, plus any deferred offers whose re-offer date has arrived.
- Apple Reminders adapter (`scripts/adapters/apple-reminders.sh`): creates,
  verifies, lists, completes, and deletes reminders via `osascript`, resolves
  the iCloud account dynamically, and builds dates via components (never
  locale-dependent string parsing).
- Decision journal (`~/.claude/cuebird/journal.jsonl`): append-only, one line
  per event; concurrency-safe via a lock-guarded append; corruption-tolerant
  reads (unparseable lines are skipped, never fatal); carries every field
  forward across status transitions (e.g. accepted → done, deferred → cancelled).
- Strict date validation in `scripts/cuebird.sh`: rejects past dates and
  calendar-invalid dates (e.g. Feb 30) with an exact round-trip check, before
  any reminder is ever created.
