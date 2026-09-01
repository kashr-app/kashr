import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/dashboard/model/period_totals.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();
final _accountId = _uuid.v4obj();

final _groceries = Tag(id: _uuid.v4obj(), name: 'Groceries');
final _transfer = Tag(
  id: _uuid.v4obj(),
  name: 'Transfer',
  semantic: TagSemantic.transfer,
);
final _tagById = {_groceries.id: _groceries, _transfer.id: _transfer};

Turnover _turnover(String amount) => Turnover(
  id: _uuid.v4obj(),
  createdAt: DateTime(2026, 1, 1),
  accountId: _accountId,
  bookingDate: DateTime(2026, 1, 15),
  amountValue: Decimal.parse(amount),
  amountUnit: 'EUR',
  purpose: 'Turnover',
);

TagTurnover _tagTurnover(String amount, {Turnover? turnover, Tag? tag}) =>
    TagTurnover(
      id: _uuid.v4obj(),
      turnoverId: turnover?.id,
      tagId: (tag ?? _groceries).id,
      amountValue: Decimal.parse(amount),
      amountUnit: 'EUR',
      createdAt: DateTime(2026, 1, 1),
      bookingDate: DateTime(2026, 1, 15),
      accountId: _accountId,
    );

PeriodTotals _totals({
  List<Turnover> turnovers = const [],
  List<TagTurnover> inPeriod = const [],
  List<TagTurnover> outside = const [],
}) => periodTotals(
  turnovers: turnovers,
  allocation: (
    allocatedInPeriod: inPeriod,
    allocatedOutsidePeriodButTurnoverInPeriod: outside,
  ),
  tagById: _tagById,
);

void main() {
  final zero = Decimal.zero;

  group('periodTotals', () {
    test('is zero without any data', () {
      expect(_totals(), (
        totalIncome: zero,
        totalExpenses: zero,
        unallocatedIncome: zero,
        unallocatedExpenses: zero,
      ));
    });

    test('counts a turnover without any tag as unallocated', () {
      final totals = _totals(turnovers: [_turnover('100'), _turnover('-40')]);

      expect(totals, (
        totalIncome: Decimal.parse('100'),
        totalExpenses: Decimal.parse('40'),
        unallocatedIncome: Decimal.parse('100'),
        unallocatedExpenses: Decimal.parse('40'),
      ));
    });

    test('counts a fully tagged turnover once', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('-100', turnover: turnover)],
      );

      expect(totals.totalExpenses, Decimal.parse('100'));
      expect(totals.unallocatedExpenses, zero);
    });

    test('splits a partially tagged turnover into tagged and rest', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('-30', turnover: turnover)],
      );

      expect(totals.totalExpenses, Decimal.parse('100'));
      expect(totals.unallocatedExpenses, Decimal.parse('70'));
    });

    test('does not count the untagged rest twice', () {
      // Regression: the total used to be tagged + 2 * untagged, which showed
      // a half-tagged income of 100 as 160.
      final turnover = _turnover('100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('40', turnover: turnover)],
      );

      expect(totals, (
        totalIncome: Decimal.parse('100'),
        totalExpenses: zero,
        unallocatedIncome: Decimal.parse('60'),
        unallocatedExpenses: zero,
      ));
    });

    test('leaves the money to the period its tag was booked into', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        outside: [_tagTurnover('-100', turnover: turnover)],
      );

      expect(totals.totalExpenses, zero);
      expect(totals.unallocatedExpenses, zero);
    });

    test('counts a tag booked here whose turnover sits elsewhere', () {
      final elsewhere = _turnover('-100');

      final totals = _totals(
        inPeriod: [_tagTurnover('-100', turnover: elsewhere)],
      );

      expect(totals.totalExpenses, Decimal.parse('100'));
      expect(totals.unallocatedExpenses, zero);
    });

    test('counts only the part that stayed in this period', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('-30', turnover: turnover)],
        outside: [_tagTurnover('-50', turnover: turnover)],
      );

      expect(totals.totalExpenses, Decimal.parse('50'));
      expect(totals.unallocatedExpenses, Decimal.parse('20'));
    });

    test('leaves a transfer out of income and expenses', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('-100', turnover: turnover, tag: _transfer)],
      );

      expect(totals.totalExpenses, zero);
      expect(totals.unallocatedExpenses, zero);
    });

    test('counts what a partial transfer left behind', () {
      final turnover = _turnover('-100');

      final totals = _totals(
        turnovers: [turnover],
        inPeriod: [_tagTurnover('-60', turnover: turnover, tag: _transfer)],
      );

      expect(totals.totalExpenses, Decimal.parse('40'));
      expect(totals.unallocatedExpenses, Decimal.parse('40'));
    });

    test('adds income and expenses side by side', () {
      final salary = _turnover('2000');
      final rent = _turnover('-800');
      final food = _turnover('-150');

      final totals = _totals(
        turnovers: [salary, rent, food],
        inPeriod: [
          _tagTurnover('2000', turnover: salary),
          _tagTurnover('-800', turnover: rent),
          _tagTurnover('-50', turnover: food),
        ],
      );

      expect(totals, (
        totalIncome: Decimal.parse('2000'),
        totalExpenses: Decimal.parse('950'),
        unallocatedIncome: zero,
        unallocatedExpenses: Decimal.parse('100'),
      ));
    });
  });

  group('taggedTotalsBySign', () {
    test('sums the absolute amounts per sign', () {
      final totals = taggedTotalsBySign([
        _tagTurnover('100'),
        _tagTurnover('20'),
        _tagTurnover('-30'),
      ], tagById: _tagById);

      expect(totals[TurnoverSign.income], Decimal.parse('120'));
      expect(totals[TurnoverSign.expense], Decimal.parse('30'));
    });

    test('skips transfer tags', () {
      final totals = taggedTotalsBySign([
        _tagTurnover('-30', tag: _transfer),
      ], tagById: _tagById);

      expect(totals, isEmpty);
    });

    test('treats an unknown tag as a normal one', () {
      final gone = Tag(id: _uuid.v4obj(), name: 'Gone');

      final totals = taggedTotalsBySign([
        _tagTurnover('-30', tag: gone),
      ], tagById: _tagById);

      expect(totals[TurnoverSign.expense], Decimal.parse('30'));
    });
  });

  group('untaggedTotalsBySign', () {
    test('ignores a tag turnover that has no turnover yet', () {
      final turnover = _turnover('-100');

      final totals = untaggedTotalsBySign(
        [turnover],
        tagTurnovers: [_tagTurnover('-100')],
      );

      expect(totals[TurnoverSign.expense], Decimal.parse('100'));
    });

    test('ignores tags of turnovers outside the period', () {
      final totals = untaggedTotalsBySign(
        [],
        tagTurnovers: [_tagTurnover('-100', turnover: _turnover('-100'))],
      );

      expect(totals, isEmpty);
    });
  });
}
