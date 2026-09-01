import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/dashboard/cubit/dashboard_cubit.dart';
import 'package:kashr/dashboard/cubit/dashboard_state.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

({Decimal expenses, int tagged, int unallocated, int tagSummaries}) _reading(
  DashboardState state,
) => (
  expenses: state.totalExpenses,
  tagged: state.tagTurnoverCount,
  unallocated: state.unallocatedCountInPeriod,
  tagSummaries: state.expenseTagSummaries.length,
);

void main() {
  useInMemoryDatabase();

  group('selectPeriod', () {
    test('shows the same month the same way, however the user got there',
        () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final tag = await app.givenTag();
      await app.givenTurnover(account, bookedOn: midThisMonth, amount: '-20');
      final onLastDay = await app.givenTurnover(
        account,
        bookedOn: lastDayOfThisMonth,
        amount: '-10',
      );
      await app.givenTagTurnover(
        account,
        tag: tag,
        bookedOn: lastDayOfThisMonth,
        amount: '-10',
        turnover: onLastDay,
      );

      final cubit = DashboardCubit(
        app.turnoverRepository,
        app.turnoverService,
        app.tagTurnoverRepository,
        app.tagRepository,
        app.transferRepository,
        app.log,
      );
      addTearDown(cubit.close);
      // Subscribing to the tag stream makes the cubit reload on its own; let
      // that finish before measuring anything.
      await cubit.loadPeriodData();
      await pumpEventQueue();

      final asOpened = cubit.state.period;
      final walkedTo = asOpened.add(delta: -1).add(delta: 1);

      await cubit.selectPeriod(asOpened);
      final opened = _reading(cubit.state);

      await cubit.selectPeriod(walkedTo);
      final walked = _reading(cubit.state);

      expect(cubit.state.status, Status.success);
      expect(walkedTo.startInclusive, asOpened.startInclusive);
      expect(walked, (
        expenses: Decimal.parse('30'),
        tagged: 1,
        unallocated: 1,
        tagSummaries: 1,
      ));
      expect(opened, walked);
    });
  });
}
