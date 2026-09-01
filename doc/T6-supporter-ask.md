# T6 — Supporter ask

## Context

Kashr is a Flutter personal finance app. It is local-first and open
source. Bank data download is the feature we ask money for.

The business model is: **never block**. The user always gets their data.
We ask honestly and let them through either way.

## Where it lives

T5 built the download sheet (`download_sheet.dart` / `download_cubit.dart`):
connecting → confirm in your banking app → downloading → result.

The ask appears **in the result state, after the data has arrived**.

Why there: the user already got what they came for, so the ask arrives
while they are satisfied. Dismissing it costs the same tap they were
going to make anyway, so it adds zero taps. And "we let you download
anyway" is literally true — the data is already on the screen.

## Rules

1. **Never block.** Nothing is disabled, delayed, or degraded. The
   download always completes.

2. **Not on every download.** Use an escalation ladder with a cap — for
   example downloads 5, 15, 40, then at most once a month. Rarity is what
   keeps the message feeling like a person instead of a mechanism. A nag
   on every use becomes a toll booth people stop reading (the WinRAR
   outcome: loved by everyone, paid by nobody).

3. **Evidence, not debt.** "You have downloaded 23 times" works as proof
   of value received. Avoid "I work for this, help me get rich" framing.
   At repeat exposure, emotional pressure turns against you.

4. **De-escalate for returning users.** Somebody coming back after months
   away should not meet the harshest rung of the ladder.

5. **The decline stays warm and equally easy to tap.** Never shame it,
   never make it visually smaller or harder to find. That is the line
   between charming and a dark pattern.

6. **Plain and warm, not jokey.** This is a finance app; trust matters
   more than comedy. Jokes also age badly on repeat and do not translate.

7. **German first.** The user base is German (comdirect, FinTS, €). Keep
   the core ask short and stable; only the wrapping text varies.

8. **Recurring price (monthly/yearly), not per download.** Per-download
   pricing makes people ration a core action. The justification is
   recurring — banks change their APIs and keeping this working is
   ongoing work — so the price should be recurring too.

## Scope

Build the ask surface and the state behind it: download count, position
on the ladder, when it was last shown, whether the user already supports.

This is the **payment gate only**. Real in-app purchase / store
integration is a separate task. The purchase action can be a placeholder.

## Do not

- Do not couple this to the staleness dot on the download FAB. That dot
  is about data freshness only. The moment a data signal doubles as a
  money signal, users stop trusting it.
- Do not put the ask anywhere except the download result.
- Do not block, delay, or degrade the download.
- Do not build store / IAP integration.

## Out of scope

Win-back push notifications for inactive users ("you have not checked
your finances in 3 months") — a separate idea for later.

## Expected result

After a download finishes, occasionally and predictably, the user sees a
short honest note about supporting Kashr, with a clear way to pay and an
equally easy way to continue. Either way, their data is already there.

Follow CLAUDE.md.
