# Changelog

## [0.1.0] — 2026-07-12

Initial public release.

- Four skills: `notifyme:remind` (proactive offer + create), `notifyme:reminders`
  (the decision journal — view, cancel, re-enable, defer, clean history),
  `notifyme:resume` (continue from a fired reminder via `«нагадування: <key>»`),
  `notifyme:doctor` (seven-point self-diagnostics, the seventh being an on-demand update check).
- `SessionStart` hook: injects one sentence of reminder-offering awareness per
  session, plus any deferred offers whose re-offer date has arrived.
- Apple Reminders adapter (`scripts/adapters/apple-reminders.sh`): creates,
  verifies, lists, completes, and deletes reminders via `osascript`, resolves
  the iCloud account dynamically, and builds dates via components (never
  locale-dependent string parsing).
- Decision journal (`~/.claude/notifyme/journal.jsonl`): append-only, one line
  per event; concurrency-safe via a lock-guarded append; corruption-tolerant
  reads (unparseable lines are skipped, never fatal); carries every field
  forward across status transitions (e.g. accepted → done, deferred → cancelled).
- Strict date validation in `scripts/notifyme.sh`: rejects past dates and
  calendar-invalid dates (e.g. Feb 30) with an exact round-trip check, before
  any reminder is ever created.
