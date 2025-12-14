## Refined Concept for Transfers

### Current Implementation and Problems

Currently Transfers are implemented like this (as can be seen in dashboard_cubit.dart):

    // Transfers can be external (one side tracked only) or internal (between tracked accounts)
    //
    // For internal transfers (between tracked accounts), the amount appears
    // twice (once negative, once positive).
    // For external transfers (to/from untracked accounts), they appear once.
    //
    // => total amount of transfers = externals.sumAbs() + internals.sumAbs()/2
    //
    // Which we can calculate as:
    // sumWithSign = sum of all tagTurnovers amounts = net sum that doesn't canacel (ie. some external)
    // sumOfAbs = sum of all tagTurnovers absolute amounts
    // External amount = abs(sumWithSign) = net sum (of values with sign) that doesn cancel
    // Internal amount = (sumOfAbs - abs(sumWithSign)) / 2
    // Total amount: external + internal/2 = (sumOfAbs + abs(sumWithSign)) / 2
    //
    // We apply that logic per tag

This solution is buggy:
* It supports internal Trandsfers only if both sides are booked in the same month
* It intends to fully support external Transfers, but it doesn't in case there are multiple external Transfers on the same Tag that at least partially cancel out each other.
    * Example: Assuming there is an external investment account and the user sees on their tracked account within the app:
        investment +10
        investment -600
        => should be 610 total transfer, but is (610+590)/2 = 600

### Solution, Decisions, Rationals

1. Only allow internal transfers (between accounts that are both available in the app)
    * Rational: Users can easily create a virtual account for the counterpart and the mental model is much easier for users and engineers.
2. Introduce a Transfer entity to explicitly model reality.
    * Rational: while this is complex, it makes the concept explicit. It fully reflects what is happening financially. This enables proper calculations, an easier mental model for users and engineers and enables a UX that hints the user about inconsistencies.

Transfer entity draft:

    class Transfer{
      @UUIDJsonConverter() required UuidValue id,
      // References the tagTurnover with negative sign, nullable because users need the flexibility to edit, delete and move around tagTurnovers
      @UUIDJsonConverter() required UuidValue? fromId, // tagTurnover
      // References the tagTurnover with positive sign, nullable because users need the flexibility to edit, delete and move around tagTurnovers
      @UUIDJsonConverter() required UuidValue? toId, // tagTurnover
      required DateTime createdAt,
    }

### Challenges
C1. A single turnover can have multiple tagTurnovers and we currently don't enforce that they all have the same semantic and we probably won't.
    * Solution: we do not match turnovers but tagTurnovers.
C2. users can change the semantics of a tag
    * Solution: Don't allow changing tag semantics. We can instead provide a button to do it but then show an info: they shall delete the tag and re-create it, which already takes care of associated tagTurnovers)
C3. Existing tagTurnovers are not yet assocaited to any Transfer entity
    * Assuming that there are two tagTurnovers representing a Transfer on differnt accounts, we still cannot automatically match them, because there could be similar ones on the same or other accounts.
C4. For tagTurnovers with transfer semantics we currently 
    * cannot guarantee that there is a counterpart turnover
    * and we cannot guarantee that if there is a counterpart turnover that it has a tagTurnover with a transfer semantic (and especially we cannot guarantee that it has the same tag).

Solution to C3 and C4: find tagTurnovers with transfer semantic that are not associated to a Transfer entity and ask the user to associate the counterpart tagTurnover.
    * They should be able to select from existing tagTurnovers with transfer semantics that are not yet associated to a Transfer entity.
        * Maybe we would also allow non-transfer tags to show up?
    * They should be able to create the matching tagTurnover with a single tap if they can't find it in the existing candidates.
    * The existing candidates could have a different tag
    * We need to enforce that the counterpart has the opposite sign. But maybe only validate but not enforce. See open Question O2.
    * We could show a similar hint like the PendingTurnoversHint on the dashboard (e.g. "2 transfers need review >")
### Other requirements
R1. We need to enforce that each tagTurnover is at most used once across all Transfer entities (the union of from_id and to_id must be unique in the table)
    * Solution: it is not a conceptual problem - just a requirement and the solution is an implementation detail. Forms should validate it and DB should enforce it.
R2. The fromId and toId must reference TagTurnovers with different accountId (cannot transfer money within a single account).
    * Solution: Forms should validate it and the DB should enforce it.
R3. The quick_turnover_entry_sheet.dart must create Transfer entities.
R4. Tag Semantic Enforcement
    * Both sides should have transfer semantics.
    * Both sides should have the same tag, because it could be confusing. E.g. having 100€ out for "invesetment transfer" and 100€ in for "fromchecking transfer" would only show the investement tag (because we only use the from for calculations) and never the fromchecking tag which would be unexpected. Or at least it would not be 100% clear what it means to have differnt tags. The stronger rational is: They should have the same tag, because it is a single operation from user perspective: I invest 100€. Other example: I withdraw 50€ from ATM.
    * None of this should be enforced, but hinted. The user is allowed to enter such data but should be warned in the editors and such invalid Transfers should show up as needing review by the user.

### Open questions
O1. It is unclear where to display the Transfers in the UI. In turnovers_page.dart we already show each side of the Transfer, so we should not list it additionally.
    * We can also not fold the two sides into a single entry, I assume the user wants to be able to edit each turnover individually (and also because a turnoer can have multiple tagTurnovers)
    * Maybe we could mark such items in the list with a tiny visual hint and on the turnover_tags_page.dart show a row that gives some information on the transfer and enables opening a Transfer details page that also allows editing and deleting it.
        * on deletion of the Transfer it should ask what should happen to the tagTurnovers: 1. delete, 2. keep (makes them dangling)
O2. What happens if the user edits the Turnover sign whose TagTurnovers are part of a Transfer?
    * Currently all TagTurnovers switch their sign automatically. This would potentially violate the invariant in Transfer objects, if there is the other side of the Transfer set and it has the same sign (Invariant is that they must be opposite sign - or we don't enforce it).
        * Maybe we should not enforce the opposite sign, but just hint the user that it is an invalid state and calculations (e.g. on the dashboard) are wrong as a consequence? We then should also mark these to be reviewed in the dashboard. Or we would forbit it and give the user some options: 1. delete the tagTurnover from the Transfer object, 2. cancel. It would for now also be ok to not provide the actual actions but just show a dialog that tells the user they manually need to remove it from the Transfer and then can try again. It might be even better, because the user better understands what the consequences of this action are if they do it manually and it is assumed to be very rarely happening.
O3. What happens when the fromId and toId in a Transfer don't have the exact same amount?
    * The naive approach is that this should not be allowed and be marked for review by the user. But what if they have different currencies? In that case the amounts would be different and we might not be able to tell if they are exact matches or not. Yet, having the user selecting them semantically means that they match (assuming the user selected the correct one).
        * if currency != currency => difference is okay, if same currency we should ask for user review. Or we always ask for review and the user can confirm (which we could store in the entity as confirmed match)
        * This could also be a problem for the dasboard calculation on how much money was transferred in the month, but I think we can solve it by just using the from side always
        =>  needsReview = NOT confirmed AND (NOT (currency identical and exact amount match) OR (currency not identical)). flag shall be persisted as `confirmedAt` and the entity should provide a getter for the derived `confirmed = confirmedAt != null`.
O4. What if bookingDate of `from` and `to` are in different months? (And what if the tagTurnover booking dates are different from their referenced Turnover entities?) Which bookingDates should inform in which month the transfer falls?
    * Or should we take it into account it in all months where either from or to happened? The consequence would be that we need in O3 to sometimes also use the `to` field for calculations. But it also is inconsistent in the way that as a user I would think of a transfer as a single operation "I move 100 EUR" and seeing it in two months I would feel like I had moved 100 EUR twice, which is not true. So we should rather decide for where it counts and my gut feel is to count it on the `from` date (but not sure if from.bookingDate or the from.turnover.bookingDate, I guess rather the from.bookingDate because the TagTurnover is the user defined bookingDate that probably best matches their expectation and it gives them the flexibility to control where it is counted in case the Turnover is uneditable (which is true for sycned accounts)).

### Other questions that were already answered
* What happens if the user deletes a TagTurnover that is part of a Transfer? => It should hint the user what will happen and let the user confirm the action and then just delete it and remove it from the Transfer.
    * Implementation hint: the deletion operation should NOT actively remove it from the Transfer, rather use ON DELETE CASCADE.
* What happens if the user unlinks a transfer-TagTurnover from a turnover? => It is not a problem and just fine. A pending tagTurnover can still be part of a Transfer.
* What happens when the tagTurnovers have an amount of Decimal.zero? It is allowed and valid.
* Should we allow a turnover to only be partially a transfer? => yes, it is why we match TagTurnovers and not Turnovers in the Transfer entity.
