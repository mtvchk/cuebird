# NotifyMe — Design Specification

**Date:** 2026-07-12
**Status:** Draft for review
**Target:** v1.0 — public open-source Claude Code plugin

## 1. Product statement

NotifyMe makes Claude Code deadline-aware. When a concrete deadline surfaces in
conversation — in any project, old or new — Claude offers, once and politely, to
set a reminder. On acceptance, the reminder lands in Apple Reminders, syncs to
the user's iPhone via iCloud within seconds, and fires **locally on the phone**
at the right moment — regardless of whether the Mac is on, Claude Code is
running, or the plugin still exists.

The product promise, in one sentence: *mention a deadline once, get reminded on
your phone, guaranteed.*

## 2. Principles

1. **Zero configuration.** No accounts, no tokens, no SQL, no apps to install.
   Apple Reminders is already on every Mac and iPhone. First use *is* the setup.
2. **Invisible until useful.** The user may forget the plugin exists. Claude
   remembers for them. No banners, no startup messages, no nagging.
3. **Native delivery.** Reminders created by NotifyMe are ordinary Apple
   Reminders: snooze, complete, edit, Siri, Apple Watch — all free, all native.
4. **Never lie about success.** Every creation is verified by reading the
   reminder back. A failure is reported in human language with exactly one
   actionable next step.
5. **Offer, never act.** A reminder is created only after explicit user consent
   in conversation. A declined offer is not repeated for that deadline.
6. **Local and private.** No telemetry, no network calls, no data leaves the
   machine (iCloud sync is Apple's, between the user's own devices).

## 3. Platform scope

| Claude Code on | Phone | v1 | Later |
|---|---|---|---|
| macOS | iPhone/iPad/Watch | ✅ Apple Reminders | — |
| macOS | Android | — | v2: ntfy adapter |
| Windows/Linux | any | — | v2: ntfy adapter |

v1 requires: macOS, Reminders app signed into iCloud, an iPhone with the same
iCloud account. The README states this limitation in the first screen — the
Apple way: narrow and flawless, honestly labeled.

## 4. User experience

### 4.1 The offer (core loop)

**User-originated deadline:**

```
User:   "цю фічу треба здати до 26 липня"
Claude: (continues the actual work, then, at a natural pause)
        "До речі — поставити нагадування на 26 липня? Прийде на iPhone."
User:   "так" / "давай на 25-го зранку"
Claude: ✓ Нагадування: «здати фічу» — 25 лип, 09:00.
        З'явиться в Reminders на всіх твоїх Apple-пристроях.
```

**Claude-originated checkpoint (equally important):** the offer triggers not
only on the user's words but on Claude's **own conclusions and plans**. When
Claude's analysis produces a concrete future decision point, it offers:

```
Claude: "...Пілотні сторінки з'явились ~10.07, для гейту потрібно 14+ днів
        стабільної індексації — раніше кінця липня перевіряти немає сенсу.

        Поставити нагадування на 24 липня — перевірити GSC Coverage
        (гейт 2: всі 9 сторінок в індексі 14+ днів)?"
```

The plugin is a proactive assistant, not an obedient command: it notices
waiting periods, verification windows, and "check back in N weeks" moments
that emerge from the work itself.

**Condition-based waits (no explicit date):** when the work produces a
waiting condition with no stated timeframe — "тепер треба почекати, поки
набереться 10 відвідувачів" — Claude estimates internally how long that
realistically takes given the current context, and offers a **check-in**
reminder at the estimated date, honestly framed as an estimate:

```
Claude: "...тепер лишається чекати, поки набереться ~10 відвідувачів.
        За моєю оцінкою, з поточним трафіком це десь 1–2 тижні.
        Поставити нагадування на 26 липня — перевірити відвідуваність?"
```

A condition check-in differs from a deadline: the reminder body and
resume_prompt record the **condition** (what to check and the threshold),
not just the date. On resume, Claude verifies the condition first — if it
is not yet met, it says so plainly and offers to re-arm the reminder for
another estimated period rather than pretending the wait is over.

Etiquette rules (encoded in the skill, non-negotiable):
- Trigger on **concrete future dates and checkpoints from either side of the
  conversation** — the user's words or Claude's own analysis. Never on
  incidental dates ("у 2024 році цей API змінився").
- Offer **once** per distinct deadline. The user's answer is nuanced, and the
  skill honors the nuance:
  - **"так"** → created.
  - **"ні"** → this specific deadline is muted — but recorded in the journal
    and reversible at any time via `/notifyme:reminders`. Declining one
    deadline never mutes other or future deadlines.
  - **"поки ні" / "спитай ближче до дати"** → deferred: journal stores a
    re-offer date, and Claude brings it up again when that date arrives.
- Offer at a natural pause, never interrupting the primary task mid-flow.
- Propose the **meaningful date** — the decision point, not the mention date
  (for "14+ днів від 10.07" that's 24.07, not today). Exactly one sensible
  option, not a menu. The user adjusts in one breath if needed.
- If the deadline is already tracked (per journal), don't re-offer; confirm
  it exists if relevant.

### 4.2 First use = onboarding

There is no setup wizard. On the very first accepted reminder:

1. Preflight runs silently: Reminders reachable? iCloud account present?
   "Claude Projects" list exists (create if not)?
2. macOS itself shows the one-time Automation permission dialog
   ("Terminal wants to control Reminders") — the OS is the onboarding UI.
3. The reminder is created, read back, confirmed.
4. One extra sentence, first time only: *"Керувати нагадуваннями можна у
   застосунку Нагадування — список 'Claude Projects'."*

Failure paths are first-class (see §10): permission denied and missing iCloud
each produce one clear sentence and one fix.

### 4.3 On demand

- `/notifyme:remind` — create a reminder explicitly ("нагадай мені 3 серпня
  про реліз").
- `/notifyme:reminders` — **the journal**: one command to see and manage the
  full decision history, filterable by project:
  - active reminders (pending, with dates)
  - fired/past ones (with cleanup offer)
  - declined offers — each reversible ("а постав все-таки оте про гейт")
  - deferred offers (with their re-offer dates)
  Natural-language actions: cancel, re-enable a declined one, defer, update a
  date, clean history. Every "так" and "ні" the user ever gave is reviewable
  and changeable here — nothing is final.
- `/notifyme:resume` — pick up where a fired reminder left off: matches the
  user's phrase against the journal, loads the stored continuation context,
  and carries on (§8.6). Also triggers naturally — "мені прийшло нагадування
  про гейт 2" works without the slash command.
- `/notifyme:doctor` — self-diagnostics (§9).

Editing reminder text/time and completing them is deliberately **not**
duplicated here — the Reminders app is the management UI (native >
reimplemented). The journal manages *decisions*; Reminders manages
*notifications*.

## 5. Architecture

```
notifyme/                          (repo root = the plugin)
├── .claude-plugin/
│   ├── plugin.json                name, version, description, author
│   └── marketplace.json           single-plugin marketplace for /plugin install
├── skills/
│   ├── remind/SKILL.md            create-reminder flow + etiquette rules
│   ├── reminders/SKILL.md         the journal: list / manage decisions
│   ├── resume/SKILL.md            continue from a fired reminder (§8.6)
│   └── doctor/SKILL.md            diagnostics + update check
├── hooks/
│   ├── hooks.json                 registers SessionStart hook
│   └── session-start.sh           echoes ONE sentence of context (~30 tokens)
├── scripts/
│   ├── notifyme.sh                CLI façade: add | list | delete | health
│   └── adapters/
│       └── apple-reminders.sh     the only v1 adapter (osascript inside)
├── README.md                      product page: promise, platforms, install
├── CHANGELOG.md
└── LICENSE                        MIT
```

### 5.1 Component responsibilities

- **skills/** — all conversation logic: when to offer, how to parse dates from
  natural language (Claude does this — no date-parsing code), how to phrase
  confirmations. Skills call `scripts/notifyme.sh` and never osascript directly.
- **scripts/notifyme.sh** — thin, stable CLI contract. Validates input
  (ISO 8601 datetime, non-empty title), routes to the configured adapter,
  maintains the local log. Testable standalone without Claude.
- **adapters/apple-reminders.sh** — all AppleScript lives here and nowhere
  else. Implements the adapter contract (§12). Replaceable in v2.
- **hooks/session-start.sh** — injects one sentence per session:
  *"NotifyMe is installed: when a concrete future deadline, checkpoint, or
  dateless waiting condition (estimate its timeframe yourself) emerges — from
  the user's words or your own analysis and plans — offer once to set a phone
  reminder (skill notifyme:remind). If the user mentions a reminder that
  fired, use skill notifyme:resume."*
  Additionally, it checks `journal.jsonl` for deferred offers whose
  `reoffer_at` has arrived and, only then, appends one line per due deferral
  so Claude re-offers it (§8.5). Cost: ~55 tokens per session, plus a line
  per due deferral (rare).

### 5.2 Data flow (create)

```
conversation → skill (parses intent+date, gets consent)
  → notifyme.sh add "2026-07-25T09:00:00+02:00" "здати фічу" "project: MyApp"
    → adapter: osascript (build date via components — locale-proof)
    → adapter: read reminder back by id  ✓ verified
    → notifyme.sh: append to ~/.claude/notifyme/reminders.jsonl
  → skill: one-line confirmation to user
```

## 6. Core mechanics (Apple Reminders adapter)

- **List:** all reminders live in list `Claude Projects` (created on demand)
  inside the **iCloud account** — resolved by enumerating accounts and
  selecting the CloudKit/iCloud one, never by hardcoded account name (which is
  localizable). If only a local ("On My Mac") account exists → explicit
  warning: phone delivery impossible, with the fix (enable Reminders in
  iCloud settings).
- **Date construction:** never `date "string"` (locale-dependent). Build via
  `current date` + set year/month/day/hours/minutes/seconds — verified
  locale-proof.
- **Title:** the user's own words, short ("здати фічу"), no prefixes — it must
  read like a reminder the user would write. Project name goes to **body**:
  `MyApp — created by NotifyMe`, so list view stays clean and provenance stays
  discoverable.
- **Verification:** `make new reminder` returns the object; adapter reads back
  its `id` and due date; only then reports success. The id is stored in the
  local log for later cancel/list.
- **Timezone:** the Mac's local timezone; the log stores full ISO 8601 with
  offset. Date-only deadlines default to 09:00 local (config-overridable).

## 7. Local state

`~/.claude/notifyme/` (created on first use):

- `config.json` — `{ "list_name": "Claude Projects", "default_hour": 9 }`.
  Defaults work for everyone; the file exists for the few who care.
- `journal.jsonl` — the single source of decision history, one line per
  event, append-only:
  `{id, status, title, due, project, project_path, context, resume_prompt,
  reminder_id?, reoffer_at?, created_at}` where `status` ∈ `accepted |
  declined | deferred | cancelled | done`. A status change appends a new line
  with the same `id` (last line wins). This one file powers the `/reminders`
  journal, dedup, deferred re-offers, the resume flow (§8.6), and doctor.
  Titles and context are stored as plain text — the file is local, and this
  is what makes declined offers reversible and fired reminders resumable.

The journal records *decisions*; Reminders remains the source of truth for
*notifications*. If they disagree (user deleted or completed a reminder in
the app), `/reminders` reconciles silently (§8).

## 8. Reminder lifecycle & smart behavior

### 8.1 One-shot by design, recurring by handoff

All v1 reminders are one-shot. For periodic needs ("заглядати в GSC раз на
кілька днів") the plugin does **not** spam interval reminders — it sets one
reminder at the next *decision point* (the earliest date when checking becomes
meaningful). If the user wants true recurrence, Claude says so honestly:
AppleScript exposes no recurrence, but adding a repeat in the Reminders app is
one tap — and the reminder NotifyMe just created is the thing to tap on.

### 8.2 Context-rich by default

A notification that fires three weeks later must be self-explanatory to a
person who has completely forgotten the context. Title stays short (what to
do); the **body** follows a fixed template, plain language, no jargon:

```
Що: перевірити, чи пройдено гейт 2 (індексація в Google)
Проєкт: MedSearch — пошук лікарів у Польщі (~/Projects/medsearch)
Критерій: усі 9 пілотних сторінок в індексі GSC 14+ днів поспіль
Далі: якщо так — розгортаємо хаб-сторінки (етап 2 SEO)

▶ Відкрий Claude Code у проєкті й скажи: «нагадування: гейт 2»

— NotifyMe
```

Four lines answer: what, where (which project, in human words), how to tell
success, and what happens next. The last line is the way back in (§8.6).

### 8.6 Resume: from notification back into a session

The journal is the deep link. At creation time, Claude writes into the
journal entry a **self-contained `resume_prompt`** — everything a fresh
session needs: project path, the state of things when the reminder was set,
what exactly to check, and the planned next steps.

When the user returns — "мені прийшло нагадування про гейт 2" or
`/notifyme:resume` — Claude matches the phrase against the journal, loads the
`resume_prompt`, and continues as if the three-week gap never happened: it
re-checks the current state, explains where things stand, and proceeds with
the plan.

Cross-device niceness, the Apple way: the reminder body's «скажи: …» phrase
can be copied on the iPhone and pasted on the Mac via Universal Clipboard —
no retyping.

True URL deep links (a custom scheme or claude.ai handoff) are a v2
exploration — no public, reliable mechanism exists today, and the
journal-based resume already delivers the experience natively.

### 8.3 After firing

Native Reminders behavior applies: the reminder stays visible (overdue) until
the user completes or snoozes it on any device. NotifyMe does not interfere.
On the next `/reminders` (or any create flow), the journal reconciles:
completed in the app → `done`; deleted in the app → `cancelled`; past-due
entries are flagged and a cleanup is *offered* ("3 нагадування вже в минулому
— прибрати з журналу?"). NotifyMe never deletes anything from Reminders on
its own.

### 8.4 Stale awareness

If the conversation reveals that a tracked reminder became irrelevant — "гейт
2 ми вже пройшли", "цей реліз скасували" — Claude offers to mark it done or
cancel it. Offer, never auto-delete: the same consent rule as creation.

### 8.5 Deferred offers

A "спитай ближче до дати" answer stores `reoffer_at` in the journal. The
SessionStart hook surfaces due deferrals: when a session starts and a
deferred offer's date has arrived, Claude re-offers it once at the first
natural pause. Deferring again is fine; the user steers.

## 9. Self-diagnostics — `/notifyme:doctor`

Runs seven checks, prints an Apple-style report (✓/✗ + one-line fix each):

1. macOS + `osascript` available
2. Automation permission for Reminders (detects error −1743/−600; fix:
   System Settings → Privacy & Security → Automation)
3. iCloud account present in Reminders (fix: enable Reminders in iCloud)
4. `Claude Projects` list exists / creatable
5. **Round-trip:** create a test reminder 2 minutes out → read back → delete.
   The only honest end-to-end proof.
6. Local state dir writable, log parseable
7. Update check (on-demand only, never automatic): compare local
   `plugin.json` version against the GitHub repo's latest release; if newer,
   print the `/plugin` update hint. This is the plugin's **only** network
   call, and only inside doctor.

## 10. Failure modes

| Failure | Detection | User sees |
|---|---|---|
| Automation permission denied | osascript error −1743 | "macOS заборонив доступ до Нагадувань. Увімкни: System Settings → Privacy & Security → Automation → Terminal → Reminders." |
| No iCloud account in Reminders | account enumeration | "Нагадування створиться лише на цьому Mac — iPhone його не побачить. Увімкни Reminders в iCloud (System Settings → Apple ID → iCloud)." + asks whether to proceed local-only |
| Reminders app missing/broken | osascript −600 | "Не бачу застосунок Нагадування. Запусти /notifyme:doctor." |
| Past date requested | notifyme.sh validation | Claude asks for a correct date (skill-level, before any script call) |
| Duplicate deadline | log lookup | No offer; on explicit /remind: "Уже стоїть на 25 лип — продублювати?" |
| osascript succeeds but read-back fails | adapter verification | "Не зміг підтвердити створення — перевір список Claude Projects. /notifyme:doctor допоможе." |

Rule: every error message ≤ 2 sentences, names the fix, never shows a stack
trace or AppleScript error text.

## 11. Privacy

- No telemetry, no analytics, no automatic network calls.
- Reminder content lives in the user's Reminders (Apple's iCloud E2E rules
  apply) and in a local log under `~/.claude/notifyme/`.
- The one network call (doctor's update check) fetches a public GitHub
  releases URL and sends nothing but the request itself.
- Stated in README verbatim.

## 12. v2 readiness — the adapter contract

Every adapter is one executable implementing:

```
adapter add <local-datetime-components> <title> <body>
                             → prints delivery-id, exit 0
adapter list                 → one "id<TAB>title" line per pending item
adapter status <delivery-id> → "pending" | "completed" | "missing"
adapter complete <delivery-id> → exit 0
adapter delete <delivery-id> → exit 0
adapter health               → exit 0 + "ok …", or nonzero + reason
```

`status` is what makes reconciliation (§8.3) possible: completed-in-app vs
deleted-in-app are different journal outcomes (`done` vs `cancelled`).

`config.json` gains `"adapter": "apple-reminders"` (default). v2 adds
`ntfy.sh` adapter (delivery: ntfy app on any phone; scheduling beyond ntfy's
3-day delay limit via cron-job.org one-shot API). Nothing in skills or
notifyme.sh changes — that is the test of the boundary.

Update path: plugin updates arrive via the standard `/plugin` marketplace
mechanism; CHANGELOG.md + semver; doctor surfaces available updates on demand.

## 13. Deliberately out of scope (v1)

- Scanning project files for deadlines (reactive-only; scanning = false
  positives = broken trust)
- Recurring reminders (AppleScript exposes no recurrence; the decision-point
  strategy + one-tap repeat handoff covers this — see §8.1)
- Editing reminder text/time from Claude (Reminders app is the editor; the
  journal §4.3 manages decisions, not notification content)
- Calendar events, non-Apple platforms, teams/sharing
- Any hosted/shared backend

## 14. Testing & release QA

- `scripts/notifyme.sh` self-check mode: `notifyme.sh selftest` — runs the
  doctor round-trip against a `Claude Projects Test` list and cleans up.
  This is the repo's runnable check (CI can't grant Automation permission, so
  selftest is a documented local gate, run before every release).
- Manual QA matrix before v1.0 tag:
  - fresh Mac / permission dialog flow, permission denied flow
  - no-iCloud (local account only) flow
  - non-English macOS locale (date construction, account enumeration)
  - date edges: tomorrow, +6 months, DST transition week, 29 Feb, date-only
  - decline → no re-offer; duplicate → no re-offer
  - iPhone receives and fires the notification (the actual product promise)
- README includes a 30-second demo GIF of the core loop.

## 15. Success criteria

1. A user who installs the plugin and never reads any docs gets offered a
   reminder the first time a deadline appears — and it fires on their iPhone.
   Zero configuration steps in between.
2. The offer also triggers on **Claude-originated** checkpoints: a session
   like the "GSC gate" example (§4.1) produces an offer with the correct
   decision-point date, without the user mentioning reminders at all.
3. Every "так"/"ні"/"пізніше" the user ever gave is visible and reversible
   through one command (`/notifyme:reminders`).
4. **The loop closes:** a fired notification, read on the phone weeks later,
   is fully self-explanatory (what/where/criterion/next) — and saying
   «нагадування: <тема>» in any Claude Code session restores the full context
   and continues the work.
5. `/notifyme:doctor` on a healthy system: 7/7 green in under 15 seconds.
6. Session overhead: ≤ 60 tokens (one hook sentence).
7. Every failure mode in §10 produces its exact message — verified manually.
