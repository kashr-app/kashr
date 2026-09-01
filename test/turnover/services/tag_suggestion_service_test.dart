import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/booking_date.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

final _bookedOn = BookingDate(2026, 1, 15);

void main() {
  useInMemoryDatabase();

  group('getSuggestionsForTurnover', () {
    test('suggests a tag the user allocates by hand, before any turnover '
        'carries it', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final tag = await app.givenTag(name: 'Groceries');
      // Pending: no turnover behind it, so the similarity pass sees nothing
      // and the frequency fallback is the only thing that can answer.
      await app.givenPending(
        account,
        tag: tag,
        bookedOn: _bookedOn,
        amount: '-50',
      );
      final turnover = await app.givenTurnover(
        account,
        bookedOn: _bookedOn,
        amount: '-20',
      );

      final suggestions = await app.suggestionService.getSuggestionsForTurnover(
        turnover,
      );

      expect(suggestions.map((it) => it.tag.id), [tag.id]);
    });

    test('leaves out tags allocated in the other direction', () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final expense = await app.givenTag(name: 'Groceries');
      final income = await app.givenTag(name: 'Salary');
      await app.givenPending(
        account,
        tag: expense,
        bookedOn: _bookedOn,
        amount: '-50',
      );
      await app.givenPending(
        account,
        tag: income,
        bookedOn: _bookedOn,
        amount: '2000',
      );
      final turnover = await app.givenTurnover(
        account,
        bookedOn: _bookedOn,
        amount: '-20',
      );

      final suggestions = await app.suggestionService.getSuggestionsForTurnover(
        turnover,
      );

      expect(suggestions.map((it) => it.tag.id), [expense.id]);
    });
  });
}
