# NotifyMe

Mention a deadline once. Get reminded on your iPhone, guaranteed.

NotifyMe makes Claude Code deadline-aware, in every project. When a concrete
deadline surfaces in conversation — yours, or a checkpoint Claude itself
plans — Claude offers, once, to set a reminder. Say yes, and it lands in
Apple Reminders, syncs to your iPhone over iCloud within seconds, and fires
**locally on the phone** at the right moment — whether your Mac is on,
Claude Code is running, or this plugin is even still installed.

## Requirements

- macOS, with the Reminders app signed into iCloud
- An iPhone (or iPad/Watch) on that same iCloud account

That's it. No accounts to create, no tokens, no config file to edit. First
use *is* the setup.

| Claude Code on | Phone | Support |
|---|---|---|
| macOS | iPhone / iPad / Watch | Apple Reminders (this release) |
| macOS | Android | planned — ntfy adapter |
| Windows / Linux | any | planned — ntfy adapter |

## Install

```
/plugin marketplace add itsmynamee/notifyme
/plugin install notifyme@notifyme
```

No further configuration. The first time you accept a reminder, macOS asks
once for permission to control Reminders — that's the only setup screen
you'll see.

## How it works

```
 1. session hook   ──  Claude quietly notes: "offer reminders when a
                        deadline appears" (~45 tokens, invisible to you)
 2. offer          ──  a deadline surfaces in conversation — yours, or
                        Claude's own plan — Claude offers once
 3. consent        ──  you say "yes" (or adjust the date in one breath)
 4. osascript      ──  Claude creates the reminder in Apple Reminders
                        and reads it back to confirm it really exists
 5. iCloud sync    ──  the reminder syncs to your other Apple devices,
                        typically within seconds
 6. phone fires    ──  your iPhone shows the notification — locally,
                        even if your Mac is off
 7. «нагадування: <key>» ── weeks later, you mention the reminder to
                        Claude in any session
 8. resume         ──  Claude loads the full context it saved and picks
                        up exactly where things left off
```

## Commands

- **`notifyme:remind`** — create a reminder explicitly ("remind me August 3rd about the release").
- **`notifyme:reminders`** — the journal: see and manage every reminder and every past decision — active, declined, deferred, done — all reversible.
- **`notifyme:resume`** — pick up the work a fired reminder was about; also triggers naturally when you mention a reminder that arrived.
- **`notifyme:doctor`** — run seven self-diagnostic checks (the seventh is an on-demand update check).

## Privacy

- No telemetry, no analytics, no automatic network calls.
- Reminder content lives in your own Reminders (Apple's iCloud end-to-end
  rules apply) and in a local log under `~/.claude/notifyme/`.
- The **only** network call NotifyMe ever makes is `notifyme:doctor`'s
  on-demand update check, which fetches a public GitHub releases URL and
  sends nothing but the request itself.

## Troubleshooting

Run `notifyme:doctor` first — it checks seven things end to end and names
the exact fix for whatever's wrong.

The two most common issues:

- **"macOS denied access to Reminders."** Go to System Settings → Privacy &
  Security → Automation → (your terminal/Claude) → enable Reminders, then
  retry.
- **"Reminders will only be created on this Mac — your iPhone won't see
  them."** Your Reminders app isn't signed into iCloud. Go to System
  Settings → Apple ID → iCloud → enable Reminders.

## Demo

![demo](docs/demo.gif)

<!-- Recorded at release: a 30-second capture of the core loop, from offer to phone notification. -->
