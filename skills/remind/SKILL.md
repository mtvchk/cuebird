---
name: remind
description: Set a phone reminder via Apple Reminders. Use PROACTIVELY when a concrete future deadline, checkpoint, waiting period, or "check back in N days/weeks" moment emerges in conversation — from the user's words OR from your own analysis and plans. Also when the user explicitly asks to be reminded of something.
---

# NotifyMe: remind

You create Apple Reminders that sync to the user's iPhone via iCloud and fire
there even when this Mac is off. The CLI lives at
`<skill-base>/../../scripts/notifyme.sh` (resolve relative to this file's own
location into one absolute path). Below, `$NOTIFYME` denotes that resolved
absolute path — it is notation, not a shell variable: each bash command you
run is its own fresh shell, so substitute the literal path directly into
every command below (or, if you do assign a shell variable, only rely on it
within one single bash invocation, never across separate tool calls). If
this file's own absolute path isn't otherwise available to you, locate the
notifyme plugin's root (the directory containing `skills/` and `scripts/`)
and build the path from there instead of guessing.

## When to offer (etiquette — non-negotiable)

- Trigger on concrete, future, actionable dates/checkpoints from EITHER side
  of the conversation: the user's words ("здати до 26-го") or your own
  conclusions ("раніше кінця липня перевіряти немає сенсу" → offer a reminder
  for the decision point). Never for incidental dates ("у 2024 цей API
  змінився").
- Offer ONCE per distinct deadline, at a natural pause — never interrupt the
  primary task mid-flow. One short sentence, e.g.:
  «До речі — поставити нагадування на 24 липня перевірити GSC Coverage?
  Прийде на iPhone.»
- Propose the MEANINGFUL date — the decision point, not the mention date.
  "14+ днів від 10.07" → offer 24.07. Exactly one option; the user adjusts.
- Before offering, check for duplicates: run `$NOTIFYME list all "<project>"`
  (the project argument scopes the check to this project) and skip the offer
  if an entry with the same intent and date already exists (any status). If
  it exists as active, you may briefly confirm it's already set.
- Time of day: if the user gave none, use the default hour from
  `~/.claude/notifyme/config.json` (`default_hour`, default 9 → 09:00).
- For periodic needs ("перевіряти раз на кілька днів") do NOT create several
  reminders — one reminder at the earliest meaningful date. If the user wants
  true recurrence, tell them: open the just-created reminder in Apple
  Reminders and add a repeat there (one tap; AppleScript cannot set it).
- **Stale awareness**: if the conversation reveals a tracked reminder became
  irrelevant or already happened («гейт ми вже пройшли», «реліз скасували»),
  offer once to close it. First find its id — run `$NOTIFYME list all
  "<project>"` and match the entry by title/intent to read its `id` field —
  then, only after the user agrees: `$NOTIFYME complete <id>` (it already
  happened) or `$NOTIFYME cancel <id>` (it never will). Offer — never close
  anything without consent. If the id turns out stale (the command reports
  the entry as not found), re-run `list all` to get the current id rather
  than guessing.

## Recording the user's answer — every answer, always

- **Yes** → create (below).
- **No** → run the command, then move on with no extra ceremony — the
  user's "no" already closes the topic, it needs no separate confirmation:
  `NOTIFYME_PROJECT="<project>" $NOTIFYME log declined "<title>" "<YYYY-MM-DDTHH:MM>"`
  Never re-offer this deadline; it stays reversible via notifyme:reminders.
- **"Not now / ask closer to the date"** → agree on a re-offer date, run the
  command below, then acknowledge in one short sentence (their language),
  e.g. «Гаразд, нагадаю ближче до дати.»:
  `NOTIFYME_PROJECT="<project>" NOTIFYME_REOFFER_AT="<YYYY-MM-DDTHH:MM>" $NOTIFYME log deferred "<title>" "<due>"`
- Declining one deadline NEVER mutes other or future deadlines.
- If a `log` command itself fails (non-zero exit, no id printed), that's a
  local bookkeeping failure only — nothing was promised in Reminders — so
  just tell the user plainly the note didn't save and continue the
  conversation. The Failure table below is about `add`/`complete`/`cancel`,
  not `log`.

## Creating

Compose:
- **title** — the user's own words, short, their language, no prefixes.
- **body** — the fixed template (their language), plain words a person who
  forgot everything will understand:
  ```
  Що: <what to do, one line>
  Проєкт: <name> — <one-line human description> (<path>)
  Критерій: <how to tell it's done/passed>
  Далі: <what happens after, one line>

  ▶ Відкрий Claude Code у проєкті й скажи: «нагадування: <short key>»

  — NotifyMe
  ```
- **resume_prompt** — a SELF-CONTAINED continuation prompt for a future
  session with zero context: project path, state of things right now, what
  exactly to check and how, planned next steps. Write it as instructions to
  a future you.

Then run as ONE bash invocation exactly as shown (env vars carry the long
fields safely — don't split this across separate tool calls):
```bash
NOTIFYME_BODY="<body>" \
NOTIFYME_PROJECT="<project name>" \
NOTIFYME_PROJECT_PATH="<absolute path>" \
NOTIFYME_CONTEXT="<one-line context>" \
NOTIFYME_RESUME_PROMPT="<resume prompt>" \
"$NOTIFYME" add "<YYYY-MM-DDTHH:MM>" "<title>"
```
Success prints `{"ok":true,...}` (exit 0). Confirm in ONE line:
«✓ Нагадування: «<title>» — <людська дата>. З'явиться на всіх твоїх
Apple-пристроях.»
Any non-zero exit → see Failure table below; don't say the line above.

**First use only** (no `~/.claude/notifyme/journal.jsonl` yet, or it's
empty): run `"$NOTIFYME" health` first, before composing anything else.
- Exit 0, prints `ok …` → proceed straight to creating.
- Exit 0, prints `ok-local …` → this is the `ok-local` row in the Failure
  table below: warn and ask before proceeding. If the user says yes, continue
  to create anyway (it will just stay Mac-only); if no, stop — don't create
  anything.
- Non-zero exit (10/11/12) → the SAME Failure table below applies to
  `health`'s own exit code exactly as it would to `add`'s. Don't attempt to
  create anything until the user has acted on the fix.

After the first successful create, add one extra sentence: «Керувати
нагадуваннями можна у застосунку Нагадування — список 'Claude Projects'.»

## Failures — exact user-facing messages (never show raw errors)

| Signal | Say (user's language, this content) |
|---|---|
| exit 10 (from `add`, `health`, `complete`, or `cancel`) | «macOS заборонив доступ до Нагадувань. Увімкни: System Settings → Privacy & Security → Automation → (твій термінал/Claude) → Reminders — і повтори.» |
| `health` → `ok-local` | «Нагадування створиться лише на цьому Mac — iPhone його не побачить. Увімкни Reminders в iCloud (System Settings → Apple ID → iCloud). Створити локально все одно?» |
| exit 11 (from `add`) | «Не зміг підтвердити створення — перевір список Claude Projects у Нагадуваннях. Запусти notifyme:doctor, якщо повториться.» (the reminder may or may not actually exist — that's exactly why this points at the list instead of asserting failure either way) |
| exit 12 | Look at stderr first, for the substrings `journal write failed` or `reminder created:`. If either appears, the Reminders-side action already succeeded (a reminder was created by `add`, or its state was changed by `complete`/`cancel`) and only the local tracking write failed — say so honestly, e.g. «Нагадування створено, але я не зберіг запис локально — перевір список Claude Projects; спробую дозаписати пізніше.» Never call this an outright failure when either substring is present. If neither substring appears, it's a genuine failure: «Щось пішло не так із застосунком Нагадування. Запусти notifyme:doctor.» |
| exit 2 (past date, calendar-invalid date like Feb 30, empty title) | Composition error on your side, never the user's — fix and retry silently, don't surface raw text. For an impossible date, stderr names the normalized date it tried (e.g. "did you mean 2026-03-02T09:00?"); use that, or otherwise recompute a valid future date yourself, and retry. Ask the user only if their intent was genuinely ambiguous. |
