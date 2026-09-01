import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

final _bookedOn = BookingDate(2026, 1, 15);
final _weekBefore = _bookedOn.addDays(-dateMatchingWindow);
final _weekAfter = _bookedOn.addDays(dateMatchingWindow);

void main() {
  useInMemoryDatabase();

  group('findMatchesForTagTurnover', () {
    test('offers a turnover booked a week later, like one booked a week '
        'earlier', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final tag = await app.givenTag();
      final earlier = await app.givenTurnover(
        account,
        bookedOn: _weekBefore,
        amount: '-50',
      );
      final later = await app.givenTurnover(
        account,
        bookedOn: _weekAfter,
        amount: '-50',
      );
      final pending = await app.givenPending(
        account,
        tag: tag,
        bookedOn: _bookedOn,
        amount: '-50',
      );

      final matches = await app.matchingService.findMatchesForTagTurnover(
        pending,
      );

      // The window is symmetric, so both edges are offered. `earlier` is the
      // control: it proves the fixture wrote and the query read.
      expect(matches.map((it) => it.turnover.id).toSet(), {
        earlier.id,
        later.id,
      });
    });
  });

  group('findMatchesForTurnover', () {
    test('offers a pending expense booked a week later, like one booked a '
        'week earlier', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final tag = await app.givenTag();
      final earlier = await app.givenPending(
        account,
        tag: tag,
        bookedOn: _weekBefore,
        amount: '-50',
      );
      final later = await app.givenPending(
        account,
        tag: tag,
        bookedOn: _weekAfter,
        amount: '-50',
      );
      final turnover = await app.givenTurnover(
        account,
        bookedOn: _bookedOn,
        amount: '-50',
      );

      final matches = await app.matchingService.findMatchesForTurnover(
        turnover,
      );

      expect(matches.map((it) => it.tagTurnover.id).toSet(), {
        earlier.id,
        later.id,
      });
    });
  });
}
