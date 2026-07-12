# Cuebird v0.1.0 Release QA Checklist

This checklist gates the `v0.1.0` tag release. All items must be checked and passing before tagging.

## Checklist

- [ ] Fresh permission flow: `tccutil reset AppleEvents` (⚠️ resets Automation permissions for ALL apps on this Mac — QA machine only) → first create shows the macOS dialog → allow → reminder created and verified.
- [ ] Permission denied flow: deny in the dialog → exact spec §10 message appears.
- [ ] GSC-style scenario: in a throwaway project, paste a plan that implies "check back in 2 weeks"; Claude offers unprompted with the decision-point date; accept; reminder body matches the §8.2 template; iPhone shows it in Reminders within a minute.
- [ ] Decline flow: say «ні» → journal has `declined`; the same deadline in a new session is NOT re-offered; cuebird:reminders can re-enable it.
- [ ] Defer flow: «спитай ближче до дати» with a past re-offer date planted → new session re-offers once.
- [ ] Resume flow: «нагадування: <key>» in a *different* directory → context restored, correct project path used, offer to complete.
- [ ] Date edges: tomorrow, +6 months, «31 числа» in a 30-day month (must be corrected by Claude, exit-2 path never shown to user), 09:00 default applied when no time given.
- [ ] Non-English macOS account: adapter health resolves the account (run on an Ukrainian-locale account if available).
- [ ] `./tests/run.sh` and `./scripts/cuebird.sh selftest` both pass on the release commit.
- [ ] Update `LICENSE`/`plugin.json`/README GitHub handle to the real one; record demo GIF; tag `v0.1.0`; create GitHub release (doctor's update check needs it).
