import 'package:decimal/decimal.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

/// The cashflow numbers the dashboard shows for one period, all absolute.
///
/// [unallocatedIncome] is the untagged *part of* [totalIncome], not an
/// amount on top of it; same for the expense pair. The summary cards print
/// the total and then list the unallocated part as one of the rows beneath
/// it, so adding it in again would show every untagged euro twice.
typedef PeriodTotals = ({
  Decimal totalIncome,
  Decimal totalExpenses,
  Decimal unallocatedIncome,
  Decimal unallocatedExpenses,
});

/// The absolute tagged amounts per sign, transfers excluded.
///
/// Transfers only move money between the user's own accounts, so counting
/// them would inflate income and expenses alike.
///
/// A tag id that is not in [tagById] counts as a normal tag: a tag we cannot
/// look up cannot be known to be a transfer, and dropping the amount would
/// silently lose money from the total.
Map<TurnoverSign, Decimal> taggedTotalsBySign(
  Iterable<TagTurnover> tagTurnovers, {
  required Map<UuidValue, Tag> tagById,
}) {
  final totals = <TurnoverSign, Decimal>{};
  for (final it in tagTurnovers) {
    if (tagById[it.tagId]?.isTransfer ?? false) continue;
    totals[it.sign] = (totals[it.sign] ?? Decimal.zero) + it.amountValue.abs();
  }
  return totals;
}

/// The absolute part of each turnover that no tag claims, per sign.
///
/// Untagged money has no booking date of its own, so it is derived rather
/// than queried: the turnover's amount minus everything tagged off it,
/// wherever those tags were booked. [tagTurnovers] therefore has to carry
/// both halves of a [TagTurnoverAllocation] - a tag booked into another
/// period has still spent the money here.
///
/// Transfer tags are deliberately not filtered out: the amount they moved is
/// spoken for and must not come back as an untagged remainder.
///
/// [TagTurnover]s without a [Turnover] are skipped. They are planned expenses
/// that no booking has matched yet, so there is no amount for them to be a
/// remainder of.
Map<TurnoverSign, Decimal> untaggedTotalsBySign(
  Iterable<Turnover> turnovers, {
  required Iterable<TagTurnover> tagTurnovers,
}) {
  final taggedByTurnoverId = <UuidValue, Decimal>{};
  for (final it in tagTurnovers) {
    final turnoverId = it.turnoverId;
    if (turnoverId == null) continue;
    taggedByTurnoverId[turnoverId] =
        (taggedByTurnoverId[turnoverId] ?? Decimal.zero) + it.amountValue;
  }

  final totals = <TurnoverSign, Decimal>{};
  for (final turnover in turnovers) {
    final tagged = taggedByTurnoverId[turnover.id] ?? Decimal.zero;
    final untagged = turnover.amountValue - tagged;
    totals[turnover.sign] =
        (totals[turnover.sign] ?? Decimal.zero) + untagged.abs();
  }
  return totals;
}

/// The cashflow totals of one period.
///
/// Money reaches a period along two different dates. A tagged amount counts
/// where its tag was booked, which is how a December purchase can be
/// budgeted into January. What is left of a turnover after its tags counts
/// where the bank booked it, because nothing else says where it belongs.
///
/// So the two sums come from different sets and are added exactly once:
/// tagged amounts from [TagTurnoverAllocation.allocatedInPeriod], untagged
/// remainders from [turnovers]. A turnover booked here whose tags all went
/// to another period contributes nothing - that is the point of the split.
PeriodTotals periodTotals({
  required Iterable<Turnover> turnovers,
  required TagTurnoverAllocation allocation,
  required Map<UuidValue, Tag> tagById,
}) {
  final tagged = taggedTotalsBySign(
    allocation.allocatedInPeriod,
    tagById: tagById,
  );
  final untagged = untaggedTotalsBySign(
    turnovers,
    tagTurnovers: [
      ...allocation.allocatedInPeriod,
      ...allocation.allocatedOutsidePeriodButTurnoverInPeriod,
    ],
  );

  Decimal untaggedOf(TurnoverSign sign) => untagged[sign] ?? Decimal.zero;

  Decimal totalOf(TurnoverSign sign) =>
      (tagged[sign] ?? Decimal.zero) + untaggedOf(sign);

  return (
    totalIncome: totalOf(TurnoverSign.income),
    totalExpenses: totalOf(TurnoverSign.expense),
    unallocatedIncome: untaggedOf(TurnoverSign.income),
    unallocatedExpenses: untaggedOf(TurnoverSign.expense),
  );
}
