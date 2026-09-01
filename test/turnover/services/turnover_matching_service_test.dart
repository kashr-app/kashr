// Fails until the date boundary bug is fixed; see test/README.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

// A January window: no DST transition within +-7 days, so the Duration
// arithmetic lands on the midnight the fixture booked.
final _bookedOn = DateTime(2026, 1, 15);
final _weekBefore = _bookedOn.subtract(
  const Duration(days: dateMatchingWindow),
);
final _weekAfter = _bookedOn.add(const Duration(days: dateMatchingWindow));

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
