import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/status.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  useInMemoryDatabase();

  group('projectedBalances', () {
    test(
      'counts what is booked on the last day of the month it projects to',
      () async {
        final app = TestApp();
        addTearDown(app.dispose);
        final account = await app.givenAccount(openingBalance: '100');
        final tag = await app.givenTag();
        await app.givenTurnover(account, bookedOn: midThisMonth, amount: '-20');
        await app.givenTurnover(
          account,
          bookedOn: lastDayOfThisMonth,
          amount: '-10',
        );
        await app.givenPending(
          account,
          tag: tag,
          bookedOn: midThisMonth,
          amount: '-3',
        );
        await app.givenPending(
          account,
          tag: tag,
          bookedOn: lastDayOfThisMonth,
          amount: '-5',
        );

        final cubit = AccountCubit(
          app.accountRepository,
          app.balanceService,
          app.turnoverRepository,
          app.log,
        );
        addTearDown(cubit.close);
        await cubit.loadAccounts();

        expect(cubit.state.status, Status.success);
        // The balance is the control: it filters by no date at all, so it is
        // right today. Only the projection, which cuts off at the end of the
        // month, loses what was booked on that very day.
        expect(
          (
            balance: cubit.state.balances[account.id],
            projectedToMonthEnd: cubit.state.projectedBalances[account.id],
          ),
          (
            balance: Decimal.parse('70'),
            projectedToMonthEnd: Decimal.parse('62'),
          ),
        );
      },
    );
  });

  group('recordDownload', () {
    test('stamps a run that only filled a gap in the history', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final caughtUpTo = BookingDate(2026, 8, 31);
      final account = await app.givenAccount(
        syncSource: SyncSource.comdirect,
        bookedThrough: caughtUpTo,
      );

      final cubit = AccountCubit(
        app.accountRepository,
        app.balanceService,
        app.turnoverRepository,
        app.log,
      );
      addTearDown(cubit.close);
      await cubit.loadAccounts();

      await cubit.recordDownload([
        account.id,
      ], bookedThrough: BookingDate(2026, 3, 1));

      // The cursor is a watermark and must not walk backwards, but the
      // download did happen - which is the whole reason the two are separate
      // fields.
      final stored = cubit.state.accountById[account.id]!;
      expect(stored.downloadCursorDate, caughtUpTo);
      expect(stored.lastDownloadAt, isNotNull);
    });

    test('moves the cursor when the run reaches further than it', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount(
        syncSource: SyncSource.comdirect,
        bookedThrough: BookingDate(2026, 3, 1),
      );

      final cubit = AccountCubit(
        app.accountRepository,
        app.balanceService,
        app.turnoverRepository,
        app.log,
      );
      addTearDown(cubit.close);
      await cubit.loadAccounts();

      await cubit.recordDownload([
        account.id,
      ], bookedThrough: BookingDate(2026, 8, 31));

      expect(
        cubit.state.accountById[account.id]!.downloadCursorDate,
        BookingDate(2026, 8, 31),
      );
    });
  });
}
