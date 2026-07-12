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

```
User:   "цю фічу треба здати до 26 липня"
Claude: (continues the actual work, then, at a natural pause)
        "До речі — поставити нагадування на 26 липня? Прийде на iPhone."
User:   "так" / "давай на 25-го зранку"
Claude: ✓ Нагадування: «NotifyMe: здати фічу» — 25 лип, 09:00.
        З'явиться в Reminders на всіх твоїх Apple-пристроях.
```

Etiquette rules (encoded in the skill, non-negotiable):
- Offer **once** per distinct deadline. Declined → logged, never re-offered.
- Offer at a natural pause, never interrupting the primary task mid-flow.
- Offer only for **concrete, future, user-owned** deadlines ("здати до 26-го"),
  never for incidental dates ("у 2024 році цей API змінився").
- Propose exactly one sensible option (date + time), not a menu. The user
  adjusts in one breath if needed.
- If the user mentions a deadline that already has a NotifyMe reminder
  (per local log), don't re-offer; confirm it exists if relevant.

### 4.2 First use = onboarding

There is no setup wizard. On the very first accepted reminder:

1. Preflight runs silently: Reminders reachable? iCloud account present?
   "Claude Projects" list exists (create if not)?
2. macOS itself shows the one-time Automation permission dialog
   ("Terminal wants to control Reminders") — the OS is the onboarding UI.
3. The reminder is created, read back, confirmed.
4. One extra sentence, first time only: *"Керувати нагадуваннями можна у
   застосунку Нагадування — список 'Claude Projects'."*

Failure paths are first-class (see §9): permission denied and missing iCloud
each produce one clear sentence and one fix.

### 4.3 On demand

- `/notifyme:remind` — create a reminder explicitly ("нагадай мені 3 серпня
  про реліз").
- `/notifyme:reminders` — list pending NotifyMe reminders (all projects or
  current project), cancel by name.
- `/notifyme:doctor` — self-diagnostics (§8).

Editing and completing reminders is deliberately **not** duplicated here — the
Reminders app is the management UI (native > reimplemented).

## 5. Architecture

```
notifyme/                          (repo root = the plugin)
├── .claude-plugin/
│   ├── plugin.json                name, version, description, author
│   └── marketplace.json           single-plugin marketplace for /plugin install
├── skills/
│   ├── remind/SKILL.md            create-reminder flow + etiquette rules
│   ├── reminders/SKILL.md         list / cancel
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
  else. Implements the adapter contract (§11). Replaceable in v2.
- **hooks/session-start.sh** — one sentence injected per session:
  *"NotifyMe is installed: when the user mentions a concrete future deadline
  for their work, offer once to set a phone reminder (notifyme:remind)."*
  This is what makes every project — old or new — deadline-aware, at a cost of
  ~30 tokens per session.

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
- `reminders.jsonl` — one line per created reminder:
  `{id, reminder_id, title, due, project, created_at}`. Powers `/reminders`,
  dedup, and doctor. Append-only; cancelled entries get `"cancelled": true`.
- `declined.jsonl` — deadlines the user declined `{project, title_hash, due}`,
  so the offer is never repeated. Nothing sensitive stored (hash, not text).

The log is a cache, not the source of truth — Reminders is. If they disagree
(user deleted a reminder in the app), `/reminders` reconciles silently.

## 8. Self-diagnostics — `/notifyme:doctor`

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

## 9. Failure modes

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

## 10. Privacy

- No telemetry, no analytics, no automatic network calls.
- Reminder content lives in the user's Reminders (Apple's iCloud E2E rules
  apply) and in a local log under `~/.claude/notifyme/`.
- The one network call (doctor's update check) fetches a public GitHub
  releases URL and sends nothing but the request itself.
- Stated in README verbatim.

## 11. v2 readiness — the adapter contract

Every adapter is one executable implementing:

```
adapter add <iso8601-datetime> <title> <body>   → prints delivery-id, exit 0
adapter list                                     → JSON lines of pending items
adapter delete <delivery-id>                     → exit 0
adapter health                                   → exit 0 + "ok", or exit 1 + reason
```

`config.json` gains `"adapter": "apple-reminders"` (default). v2 adds
`ntfy.sh` adapter (delivery: ntfy app on any phone; scheduling beyond ntfy's
3-day delay limit via cron-job.org one-shot API). Nothing in skills or
notifyme.sh changes — that is the test of the boundary.

Update path: plugin updates arrive via the standard `/plugin` marketplace
mechanism; CHANGELOG.md + semver; doctor surfaces available updates on demand.

## 12. Deliberately out of scope (v1)

- Scanning project files for deadlines (reactive-only; scanning = false
  positives = broken trust)
- Recurring reminders (AppleScript exposes no recurrence; user can add
  recurrence in the Reminders app afterward)
- Editing reminders from Claude (Reminders app is the editor)
- Calendar events, non-Apple platforms, teams/sharing
- Any hosted/shared backend

## 13. Testing & release QA

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

## 14. Success criteria

1. A user who installs the plugin and never reads any docs gets offered a
   reminder the first time they mention a deadline — and it fires on their
   iPhone. Zero configuration steps in between.
2. `/notifyme:doctor` on a healthy system: 7/7 green in under 15 seconds.
3. Session overhead: ≤ 40 tokens (one hook sentence).
4. Every failure mode in §9 produces its exact message — verified manually.
