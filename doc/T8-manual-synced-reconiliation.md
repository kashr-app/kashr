# T8 — Manual ↔ synced reconciliation

## Context

Kashr is a Flutter personal finance app. Bank download is a paid feature,
so most new users start by entering transactions by hand.

The expected journey: someone tracks "Checking" manually for weeks, then
connects their real bank and wants that account to become the synced one
— keeping the history they typed.

This is a normal, supported flow, not a repair of a user mistake. The app
already promises it during account creation: "You can connect this
account to your bank later."

## The problem (found during design — verify before building)

- A manual entry creates **both** a `Turnover` and a `TagTurnover`,
  already matched to each other.
- `TurnoverMatchingService` only considers **unmatched** candidates on
  both sides (`findMatchesForTagTurnover`,
  `getUnmatchedTurnoversForAccount`).
- So when the bank later delivers that same real transaction, the
  incoming `Turnover` finds no unmatched `TagTurnover` to pair with and
  simply lands as a second `Turnover` on the account.
- The balance is `openingBalance + sum(all turnovers)`
  (`BalanceCalculationService`), so **every overlapping transaction is
  counted twice**.

## Direction (not a plan)

For a newly linked account: find manual turnovers (`apiId == null`) that
match downloaded ones (`apiId != null`), re-point the manual
`TagTurnover` at the bank `Turnover`, and delete the manual `Turnover`.

The confidence scoring in `TurnoverMatchingService` is reusable. The
"unmatched only" repository queries are not — that is exactly the
assumption that breaks here.

## Design questions to settle with the user first

- **Opening balance.** The manual account has an opening balance the user
  typed. The real account has its own history and starting point. What
  happens to the opening balance when they are linked?
- **How far back the bank goes.** FinTS / PSD2 typically caps history at
  around 90 days. That window is exactly where hand-entered and
  downloaded data collide, so the overlap is the normal case, not an edge
  case. Transactions older than the bank's window stay manual forever and
  must keep working.
- **What the user sees and confirms.** Silently merging money data is not
  acceptable. Auto-match only when confident; ask otherwise.
- **Starting cursor.** T5 added a per-account `downloadCursorDate`
  (null = never downloaded). A newly linked account needs a sensible one.

## Expected result

Linking a manual account to a real bank account keeps the user's history,
does not duplicate transactions, and never changes balances behind their
back.

## Related

`doc/T7-discovered-accounts-screen.md` — its "Link to existing" option
must not ship before this task is done.

Follow CLAUDE.md.
