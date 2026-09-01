import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

Account _account({
  SyncSource? syncSource = SyncSource.comdirect,
  BookingDate? downloadCursorDate,
}) => Account(
  id: _uuid.v4obj(),
  createdAt: DateTime(2026, 1, 1),
  name: 'Account',
  accountType: AccountType.checking,
  syncSource: syncSource,
  currency: 'EUR',
  openingBalance: Decimal.zero,
  downloadCursorDate: downloadCursorDate,
  isHidden: false,
);

void main() {
  final today = BookingDate(2026, 8, 31);

  group('periodDownloadRange', () {
    test('covers a past period end to end', () {
      final period = Period.of(BookingDate(2026, 6, 15), PeriodType.month);

      final range = periodDownloadRange(period, today: today);

      expect(range, isNotNull);
      expect(range!.startInclusive, BookingDate(2026, 6, 1));
      expect(range.endInclusive, BookingDate(2026, 6, 30));
    });

    test('stops at today rather than asking for days not yet booked', () {
      final period = Period.of(today, PeriodType.month);

      final range = periodDownloadRange(period, today: today);

      expect(range!.startInclusive, BookingDate(2026, 8, 1));
      expect(range.endInclusive, today);
    });

    test('has nothing to fetch for a period that has not begun', () {
      final period = Period.of(BookingDate(2026, 10, 5), PeriodType.month);

      expect(periodDownloadRange(period, today: today), isNull);
    });

    test('offers a period that begins today', () {
      final period = Period(
        PeriodType.month,
        startInclusive: today,
        endExclusive: today.addDays(30),
      );

      final range = periodDownloadRange(period, today: today);

      expect(range, isNotNull);
      expect(range!.startInclusive, today);
      expect(range.endInclusive, today);
    });
  });

  group('isFirstDownload', () {
    test('is true when nothing was ever downloaded', () {
      expect(isFirstDownload([_account(), _account()]), isTrue);
    });

    test('is true when no account exists yet', () {
      expect(isFirstDownload([]), isTrue);
    });

    test('ignores manual accounts', () {
      final accounts = [
        _account(syncSource: SyncSource.manual),
        _account(syncSource: null),
      ];

      expect(isFirstDownload(accounts), isTrue);
    });

    test('is false once one account has a cursor', () {
      final accounts = [
        _account(),
        _account(downloadCursorDate: BookingDate(2026, 8, 20)),
      ];

      expect(isFirstDownload(accounts), isFalse);
    });
  });

  group('startInclusiveFor', () {
    final request = DownloadRequest.upTo(
      endInclusive: today,
      startInclusive: BookingDate(2026, 1, 1),
    );

    test('re-fetches the overlap before the cursor', () {
      final account = _account(downloadCursorDate: BookingDate(2026, 8, 20));

      final min = startInclusiveFor(
        account,
        request: request,
        startInclusiveWithoutCursor: null,
      );

      expect(min, BookingDate(2026, 8, 20).addDays(-14));
    });

    test('starts a cursorless account where the oldest one already is', () {
      final min = startInclusiveFor(
        _account(),
        request: request,
        startInclusiveWithoutCursor: BookingDate(2026, 7, 1),
      );

      expect(min, BookingDate(2026, 7, 1));
    });

    test('falls back to the requested start without any cursor', () {
      final min = startInclusiveFor(
        _account(),
        request: request,
        startInclusiveWithoutCursor: null,
      );

      expect(min, BookingDate(2026, 1, 1));
    });

    test('ignores the cursor when the user widened the range', () {
      final widened = DownloadRequest.upTo(
        endInclusive: today,
        startInclusive: BookingDate(2025, 1, 1),
        ignoreCursors: true,
      );

      final min = startInclusiveFor(
        _account(downloadCursorDate: BookingDate(2026, 8, 20)),
        request: widened,
        startInclusiveWithoutCursor: null,
      );

      expect(min, BookingDate(2025, 1, 1));
    });
  });

  group('unionDownloadRange', () {
    test('spans the oldest effective start up to the requested end', () {
      final accounts = [
        _account(downloadCursorDate: BookingDate(2026, 8, 20)),
        _account(downloadCursorDate: BookingDate(2026, 6, 30)),
      ];

      final range = unionDownloadRange(
        accounts,
        request: DownloadRequest.upTo(
          endInclusive: today,
          startInclusive: BookingDate(2026, 1, 1),
        ),
      );

      expect(range.startInclusive, BookingDate(2026, 6, 30).addDays(-14));
      expect(range.endInclusive, today);
    });

    test('falls back to the requested start without accounts', () {
      final range = unionDownloadRange(
        [],
        request: DownloadRequest.upTo(
          endInclusive: today,
          startInclusive: BookingDate(2026, 5, 1),
        ),
      );

      expect(range.startInclusive, BookingDate(2026, 5, 1));
    });
  });

  group('isDownloadStale', () {
    test('is false without any downloadable account', () {
      final accounts = [_account(syncSource: SyncSource.manual)];

      expect(isDownloadStale(accounts, today: today), isFalse);
    });

    test('is true for an account that was never downloaded', () {
      expect(isDownloadStale([_account()], today: today), isTrue);
    });

    test('is true once the oldest cursor is behind', () {
      final accounts = [
        _account(downloadCursorDate: today),
        _account(downloadCursorDate: BookingDate(2026, 8, 27)),
      ];

      expect(isDownloadStale(accounts, today: today), isTrue);
    });

    test('is false while every cursor is recent enough', () {
      final accounts = [
        _account(downloadCursorDate: today),
        _account(downloadCursorDate: BookingDate(2026, 8, 28)),
      ];

      expect(isDownloadStale(accounts, today: today), isFalse);
    });
  });

  group('DownloadRequest.between', () {
    test('keeps both picked ends, stripped to booking dates', () {
      final request = DownloadRequest.between(
        startInclusive: BookingDate.on(DateTime(2026, 3, 5, 14, 30)),
        endInclusive: BookingDate.on(DateTime(2026, 4, 20, 9, 15)),
      );

      expect(request.startInclusive, BookingDate(2026, 3, 5));
      expect(request.endInclusive, BookingDate(2026, 4, 20));
    });

    test('spans a picked range that ends in the past', () {
      final accounts = [_account(downloadCursorDate: BookingDate(2026, 8, 20))];

      final range = unionDownloadRange(
        accounts,
        request: DownloadRequest.between(
          startInclusive: BookingDate(2026, 3, 1),
          endInclusive: BookingDate(2026, 4, 30),
          ignoreCursors: true,
        ),
      );

      expect(range.startInclusive, BookingDate(2026, 3, 1));
      expect(range.endInclusive, BookingDate(2026, 4, 30));
    });
  });

  group('DownloadDepth', () {
    test('counts back the offered months', () {
      expect(
        DownloadDepth.threeMonths.startInclusive(today),
        BookingDate(2026, 5, 31),
      );
      expect(
        DownloadDepth.twelveMonths.startInclusive(today),
        BookingDate(2025, 8, 31),
      );
    });

    test('asks for more history than a bank is likely to keep', () {
      expect(
        DownloadDepth.everything
            .startInclusive(today)
            .isBefore(BookingDate(2010, 1, 1)),
        isTrue,
      );
    });
  });
}
