#!/bin/bash
# Cuebird delivery adapter: Apple Reminders via EventKit (JXA).
# Contract: add | list | status | complete | delete | health | droplist
# One Reminders list per project, named like the project; the user may group
# them (e.g. a "Claude Projects" group) by hand.
#
# Why EventKit and not AppleScript: AppleScript cannot see lists inside a list
# group at all (every list / list id / list "name" all fail), EventKit can.
# Reminder ids are the same UUID in both, so pre-0.2 journal ids keep working.
# Grouping is deliberately NOT automated: only Shortcuts can touch groups, and
# its name→list lookup proved nondeterministic headless (pickers, queued runs).
set -uo pipefail
STATE_DIR="${CUEBIRD_STATE_DIR:-$HOME/.claude/cuebird}"

# Exit codes: 10 permission denied, 11 verify failed, 12 other failure
ek() { # $1: mode, then mode args. stdout = result; exit code from $.exit
  CUEBIRD_MAP="$STATE_DIR/lists.json" /usr/bin/osascript -l JavaScript - "$@" <<'EOF'
ObjC.import('EventKit'); ObjC.import('stdlib');
const REM = 1; // EKEntityTypeReminder
function die(code, msg) { console.log(msg); $.exit(code); }
function env(k) { const v = $.NSProcessInfo.processInfo.environment.objectForKey(k); return v.isNil() ? '' : ObjC.unwrap(v); }
function openStore() {
  if ($.EKEventStore.authorizationStatusForEntityType(REM) == 0) { // not determined → ask once
    let done = false;
    const s = $.EKEventStore.alloc.init;
    const cb = () => { done = true; };
    if (s.respondsToSelector('requestFullAccessToRemindersWithCompletion:')) s.requestFullAccessToRemindersWithCompletion(cb);
    else s.requestAccessToEntityTypeCompletion(REM, cb);
    const until = $.NSDate.dateWithTimeIntervalSinceNow(120);
    while (!done && $.NSDate.date.compare(until) < 0) $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.2));
  }
  if ($.EKEventStore.authorizationStatusForEntityType(REM) != 3) die(10, 'permission');
  return $.EKEventStore.alloc.init;
}
function pickSource(s) { // iCloud if present, else wherever new reminders go (Mac-only)
  const srcs = s.sources;
  for (let i = 0; i < srcs.count; i++) { const x = srcs.objectAtIndex(i); if (x.title.js === 'iCloud') return { src: x, local: false }; }
  const def = s.defaultCalendarForNewReminders;
  if (def.isNil()) die(12, 'no reminders account');
  return { src: def.source, local: true };
}
function readMap() {
  const t = $.NSString.stringWithContentsOfFileEncodingError(env('CUEBIRD_MAP'), $.NSUTF8StringEncoding, null);
  try { return t.isNil() ? {} : JSON.parse(ObjC.unwrap(t)); } catch (e) { return {}; }
}
function writeMap(m) {
  // Deliberate simplification: no lock, two first-ever adds for one project at the same instant make two lists
  $.NSString.alloc.initWithUTF8String(JSON.stringify(m, null, 1) + '\n')
    .writeToFileAtomicallyEncodingError(env('CUEBIRD_MAP'), true, $.NSUTF8StringEncoding, null);
}
function save(fn) { const e = Ref(); if (!fn(e)) die(12, e[0].localizedDescription.js); }
function item(s, id) { return s.calendarItemWithIdentifier(id.replace('x-apple-reminder://', '')); }
function projectList(s, project) {
  // Map by id, not name: a list the user renamed or grouped is still found.
  const m = readMap(), known = m[project] ? s.calendarWithIdentifier(m[project]) : $();
  if (!known.isNil()) return known;
  const c = $.EKCalendar.calendarForEntityTypeEventStore(REM, s);
  c.title = project; c.source = pickSource(s).src;
  save(e => s.saveCalendarCommitError(c, true, e));
  m[project] = c.calendarIdentifier.js; writeMap(m);
  return c;
}
function run(a) {
  const mode = a[0], s = openStore();
  if (mode === 'health') { const p = pickSource(s); return (p.local ? 'ok-local ' : 'ok ') + p.src.title.js; }
  if (mode === 'add') { // y m d H M title body project
    const r = $.EKReminder.reminderWithEventStore(s);
    r.calendar = projectList(s, a[8] || 'Cuebird'); r.title = a[6]; r.notes = a[7];
    const dc = $.NSDateComponents.alloc.init;
    dc.year = +a[1]; dc.month = +a[2]; dc.day = +a[3]; dc.hour = +a[4]; dc.minute = +a[5];
    r.dueDateComponents = dc;
    r.addAlarm($.EKAlarm.alarmWithAbsoluteDate($.NSCalendar.currentCalendar.dateFromComponents(dc)));
    save(e => s.saveReminderCommitError(r, true, e));
    const back = $.EKEventStore.alloc.init.calendarItemWithIdentifier(r.calendarItemIdentifier); // fresh store: really persisted?
    if (back.isNil() || back.title.js !== a[6]) die(11, 'verify failed');
    return r.calendarItemIdentifier.js;
  }
  if (mode === 'status') { const r = item(s, a[1]); return r.isNil() ? 'missing' : (r.completed ? 'completed' : 'pending'); }
  if (mode === 'complete') { const r = item(s, a[1]); if (r.isNil()) die(12, 'missing'); r.completed = true; save(e => s.saveReminderCommitError(r, true, e)); return; }
  if (mode === 'delete') { const r = item(s, a[1]); if (!r.isNil()) save(e => s.removeReminderCommitError(r, true, e)); return; }
  if (mode === 'list') { // id<TAB>title per pending reminder across project lists
    const cals = $.NSMutableArray.array;
    Object.values(readMap()).forEach(id => { const c = s.calendarWithIdentifier(id); if (!c.isNil()) cals.addObject(c); });
    if (!cals.count) return;
    let done = false, got = $();
    s.fetchRemindersMatchingPredicateCompletion(s.predicateForIncompleteRemindersWithDueDateStartingEndingCalendars($(), $(), cals), r => { got = r; done = true; });
    while (!done) $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.05));
    const out = [];
    for (let i = 0; i < got.count; i++) { const r = got.objectAtIndex(i); out.push(r.calendarItemIdentifier.js + '\t' + r.title.js); }
    return out.join('\n');
  }
  if (mode === 'droplist') { // tests/selftest only: delete a project's list and forget it
    const m = readMap(), c = m[a[1]] ? s.calendarWithIdentifier(m[a[1]]) : $();
    if (!c.isNil()) save(e => s.removeCalendarCommitError(c, true, e));
    delete m[a[1]]; writeMap(m); return;
  }
  die(2, 'unknown command: ' + mode);
}
EOF
}

case "${1:-}" in
  health|status|complete|delete|droplist) ek "$@" ;;
  add) [ $# -ge 8 ] || { echo "add needs: y m d H M title body [project]" >&2; exit 2; }; ek "$@" ;;
  list) out=$(ek list) || exit $?; [ -n "$out" ] && printf '%s\n' "$out"; exit 0 ;;
  *) echo "unknown command: ${1:-}" >&2; exit 2 ;;
esac
