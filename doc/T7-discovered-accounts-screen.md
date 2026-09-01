# T7 — Discovered accounts screen

> **Depends on T8.** See "Blocking dependency" below. Do not ship the
> "Link to existing" option before T8 is done.

## Context

Kashr is a Flutter personal finance app. It downloads transactions from
comdirect (more banks later, likely via FinTS).

Today, on the first download, the app detects the accounts at the bank
and creates them in the app automatically. The user has no say in it.

That causes two problems:

- The user gets accounts they did not ask for and may not want.
- A user who already tracks a "Checking" account by hand ends up with two
  accounts for the same real account.

The second one matters more than it looks: bank download is a paid
feature, so most new users start with manual accounts on purpose. Ending
up with a manual account next to the real one is the **normal path**, not
a mistake.

## Goal

After a bank connects, show what was found and let the user decide per
account:

- **Add** — create it in Kashr (what happens automatically today).
- **Link to existing** — connect a manual account the user already keeps
  by hand to this real bank account.
- **Ignore** — do not create it, and remember that, so the user is not
  asked again on every download.

## Blocking dependency

**"Link to existing" must stay hidden or disabled until T8 is done.**

Without T8, linking double-counts every overlapping transaction and
silently corrupts the account balance. See
`doc/T8-manual-synced-reconilliation.md`.

Everything else in this task (Add / Ignore, remembering Ignore, replacing
silent auto-creation) can ship on its own.

## Design rules

- **No gates. Every screen is an on-ramp.** Do not fail, do not show a
  red error for a state the app could predict.
- **Never tell the user that creating a manual account was a mistake.**
  It is a supported path, and the app promises elsewhere: "You can
  connect this account to your bank later." This screen is where that
  promise gets kept.
- An account's source is not permanent. Manual → synced is a supported
  change, not a repair.

## Notes

- T5 added a per-account `downloadCursorDate` (null = never downloaded).
  A newly added account needs a sensible starting cursor — check how
  `comdirect_service.dart` derives each account's minimum booking date.
- A future paywall might limit how many accounts download. Do not build
  that, but do not make it impossible either.

## Expected result

Connecting a bank no longer silently creates accounts. The user sees what
was found and chooses what happens to each one. Ignored accounts stay
ignored.

Follow CLAUDE.md.
