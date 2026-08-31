import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

Account _account({
  SyncSource? syncSource = SyncSource.comdirect,
  DateTime? downloadCursorDate,
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
  final today = DateTime(2026, 8, 31);

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
        _account(downloadCursorDate: DateTime(2026, 8, 20)),
      ];

      expect(isFirstDownload(accounts), isFalse);
    });
  });

  group('minBookingDateFor', () {
    final request = DownloadRequest.upTo(
      today,
      startDate: DateTime(2026, 1, 1),
    );

    test('re-fetches the overlap before the cursor', () {
      final account = _account(downloadCursorDate: DateTime(2026, 8, 20));

      final min = minBookingDateFor(
        account,
        request: request,
        startDateWithoutCursor: null,
      );

      expect(min, DateTime(2026, 8, 20).subtract(Duration(days: 14)));
    });

    test('starts a cursorless account where the oldest one already is', () {
      final min = minBookingDateFor(
        _account(),
        request: request,
        startDateWithoutCursor: DateTime(2026, 7, 1),
      );

      expect(min, DateTime(2026, 7, 1));
    });

    test('falls back to the requested start without any cursor', () {
      final min = minBookingDateFor(
        _account(),
        request: request,
        startDateWithoutCursor: null,
      );

      expect(min, DateTime(2026, 1, 1));
    });

    test('ignores the cursor when the user widened the range', () {
      final widened = DownloadRequest.upTo(
        today,
        startDate: DateTime(2025, 1, 1),
        ignoreCursors: true,
      );

      final min = minBookingDateFor(
        _account(downloadCursorDate: DateTime(2026, 8, 20)),
        request: widened,
        startDateWithoutCursor: null,
      );

      expect(min, DateTime(2025, 1, 1));
    });
  });

  group('unionDownloadRange', () {
    test('spans the oldest effective start up to the requested end', () {
      final accounts = [
        _account(downloadCursorDate: DateTime(2026, 8, 20)),
        _account(downloadCursorDate: DateTime(2026, 6, 30)),
      ];

      final range = unionDownloadRange(
        accounts,
        request: DownloadRequest.upTo(today, startDate: DateTime(2026, 1, 1)),
      );

      expect(range.min, DateTime(2026, 6, 30).subtract(Duration(days: 14)));
      expect(range.max, today);
    });

    test('falls back to the requested start without accounts', () {
      final range = unionDownloadRange(
        [],
        request: DownloadRequest.upTo(today, startDate: DateTime(2026, 5, 1)),
      );

      expect(range.min, DateTime(2026, 5, 1));
    });
  });

  group('isDownloadStale', () {
    test('is false without any downloadable account', () {
      final accounts = [_account(syncSource: SyncSource.manual)];

      expect(isDownloadStale(accounts, now: today), isFalse);
    });

    test('is true for an account that was never downloaded', () {
      expect(isDownloadStale([_account()], now: today), isTrue);
    });

    test('is true once the oldest cursor is behind', () {
      final accounts = [
        _account(downloadCursorDate: today),
        _account(downloadCursorDate: DateTime(2026, 8, 27)),
      ];

      expect(isDownloadStale(accounts, now: today), isTrue);
    });

    test('is false while every cursor is recent enough', () {
      final accounts = [
        _account(downloadCursorDate: today),
        _account(downloadCursorDate: DateTime(2026, 8, 28)),
      ];

      expect(isDownloadStale(accounts, now: today), isFalse);
    });
  });

  group('DownloadRequest.between', () {
    test('keeps both picked ends, stripped to booking dates', () {
      final request = DownloadRequest.between(
        startDate: DateTime(2026, 3, 5, 14, 30),
        endDate: DateTime(2026, 4, 20, 9, 15),
      );

      expect(request.startDate, DateTime(2026, 3, 5));
      expect(request.maxBookingDate, DateTime(2026, 4, 20));
    });

    test('spans a picked range that ends in the past', () {
      final accounts = [_account(downloadCursorDate: DateTime(2026, 8, 20))];

      final range = unionDownloadRange(
        accounts,
        request: DownloadRequest.between(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 4, 30),
          ignoreCursors: true,
        ),
      );

      expect(range.min, DateTime(2026, 3, 1));
      expect(range.max, DateTime(2026, 4, 30));
    });
  });

  group('DownloadDepth', () {
    test('counts back the offered months', () {
      expect(DownloadDepth.threeMonths.startDate(today), DateTime(2026, 5, 31));
      expect(DownloadDepth.twelveMonths.startDate(today), DateTime(2025, 8, 31));
    });

    test('asks for more history than a bank is likely to keep', () {
      expect(
        DownloadDepth.everything.startDate(today).isBefore(DateTime(2010)),
        isTrue,
      );
    });
  });
}
