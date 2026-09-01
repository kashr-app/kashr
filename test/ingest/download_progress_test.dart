import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/ingest/download_progress.dart';
import 'package:kashr/ingest/download_range.dart';

void main() {
  group('downloadProgressText', () {
    test('says what it always said when nothing was reported yet', () {
      final text = downloadProgressText(null);

      expect(text.title, 'Downloading transactions…');
      expect(text.detail, isNull);
    });

    test('names the account it is on', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(subject: 'Girokonto'),
      );

      expect(text.title, 'Downloading Girokonto…');
    });

    test('falls back to the general sentence for a nameless subject', () {
      final text = downloadProgressText(const DownloadProgress.fetching());

      expect(text.title, 'Downloading transactions…');
    });

    test('counts the accounts while it is still finding them', () {
      final text = downloadProgressText(
        const DownloadProgress.findingAccounts(done: 3, total: 12),
      );

      expect(text.title, 'Looking for your accounts…');
      expect(text.detail, '3 of 12 accounts');
    });

    test('puts the position and the count on one line', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(
          subject: 'Girokonto',
          subjectIndex: 2,
          subjectCount: 3,
          done: 350,
          total: 1240,
        ),
      );

      expect(text.detail, 'Account 2 of 3 · 350 of 1240 transactions');
    });

    test('hides the position when there is only one account', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(
          subject: 'Girokonto',
          subjectIndex: 1,
          subjectCount: 1,
          done: 350,
          total: 1240,
        ),
      );

      expect(text.detail, '350 of 1240 transactions');
    });

    test('hides the position until both numbers are known', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(subject: 'Girokonto', subjectIndex: 2),
      );

      expect(text.detail, isNull);
    });

    test('says so far while the source is still counting', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(subject: 'Girokonto', done: 50),
      );

      expect(text.detail, '50 transactions so far');
    });

    test('says nothing about a count that has not started', () {
      final text = downloadProgressText(
        const DownloadProgress.fetching(subject: 'Girokonto', done: 0),
      );

      expect(text.detail, isNull);
    });

    test('names how much there is to save', () {
      final text = downloadProgressText(
        const DownloadProgress.saving(total: 2480),
      );

      expect(text.title, 'Saving what arrived…');
      expect(text.detail, '2480 transactions');
    });

    test('counts the matching as it goes', () {
      final text = downloadProgressText(
        const DownloadProgress.matching(done: 900, total: 2480),
      );

      expect(text.title, 'Matching them to your tags…');
      expect(text.detail, '900 of 2480 matched');
    });

    test('holds the matching line until there is a total to match against', () {
      final text = downloadProgressText(const DownloadProgress.matching());

      expect(text.detail, isNull);
    });
  });

  group('DownloadProgressSink', () {
    final window = DownloadRange(
      startInclusive: BookingDate(2026, 1, 1),
      endInclusive: BookingDate(2026, 8, 31),
    );

    test('passes every distinct report on when nothing is held back', () {
      final seen = <DownloadProgress>[];
      final sink = DownloadProgressSink(seen.add, minInterval: Duration.zero);

      sink.report(const DownloadProgress.fetching(done: 1));
      sink.report(const DownloadProgress.fetching(done: 2));
      sink.report(const DownloadProgress.fetching(done: 3));

      expect(seen, [
        const DownloadProgress.fetching(done: 1),
        const DownloadProgress.fetching(done: 2),
        const DownloadProgress.fetching(done: 3),
      ]);
    });

    test('drops a report that says the same as the last one', () {
      final seen = <DownloadProgress>[];
      final sink = DownloadProgressSink(seen.add, minInterval: Duration.zero);

      sink.report(DownloadProgress.fetching(done: 1, window: window));
      sink.report(DownloadProgress.fetching(done: 1, window: window));

      expect(seen, hasLength(1));
    });

    test('coalesces a tight loop down to the first report', () {
      final seen = <DownloadProgress>[];
      final sink = DownloadProgressSink(
        seen.add,
        minInterval: const Duration(minutes: 1),
      );

      for (var done = 0; done < 1000; done++) {
        sink.report(DownloadProgress.matching(done: done, total: 1000));
      }

      expect(seen, hasLength(1));
      expect(seen.single.done, 0);
    });

    test('never holds back a change of phase', () {
      final seen = <DownloadProgress>[];
      final sink = DownloadProgressSink(
        seen.add,
        minInterval: const Duration(minutes: 1),
      );

      sink.report(const DownloadProgress.fetching(done: 1));
      sink.report(const DownloadProgress.fetching(done: 2));
      sink.report(const DownloadProgress.saving(total: 2));
      sink.report(const DownloadProgress.matching(done: 0, total: 2));

      expect(seen.map((it) => it.phase), [
        DownloadPhase.fetching,
        DownloadPhase.saving,
        DownloadPhase.matching,
      ]);
    });

    test('says nothing at all when nobody is watching', () {
      final sink = DownloadProgressSink.discard();

      sink.report(const DownloadProgress.fetching(done: 1));
    });
  });

  group('DownloadRange', () {
    test('is equal to another range over the same days', () {
      final range = DownloadRange(
        startInclusive: BookingDate(2026, 1, 1),
        endInclusive: BookingDate(2026, 8, 31),
      );
      final same = DownloadRange(
        startInclusive: BookingDate(2026, 1, 1),
        endInclusive: BookingDate(2026, 8, 31),
      );
      final shorter = DownloadRange(
        startInclusive: BookingDate(2026, 1, 1),
        endInclusive: BookingDate(2026, 8, 30),
      );

      expect(range, same);
      expect(range.hashCode, same.hashCode);
      expect(range, isNot(shorter));
    });
  });
}
