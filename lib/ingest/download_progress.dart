import 'package:kashr/ingest/download_range.dart';
import 'package:meta/meta.dart';

/// The kind of work a download is doing, in the steps every source shares.
///
/// Closed on purpose and small on purpose: it exists so the sheet can say one
/// true sentence, not so an ingestor can narrate itself. A source whose work
/// has a name nobody outside it would recognise reports [fetching] with its
/// own [DownloadProgress.subject], which is the part the user cares about.
enum DownloadPhase {
  /// Asking the source which accounts it has.
  findingAccounts,

  /// Pulling transactions for one subject.
  fetching,

  /// Writing what arrived.
  saving,

  /// Pairing what arrived with the tags the user already uses.
  matching,
}

/// What a running download is doing, in terms no single source owns.
///
/// Every field but [phase] is optional because sources know different things:
/// comdirect learns the exact number of transactions from the first page of
/// each account, while a source that walks history in chunks only ever knows
/// which window it asked for. Absent means unknown, never zero - a guessed
/// denominator turns into a count that walks backwards.
@immutable
class DownloadProgress {
  final DownloadPhase phase;

  /// What is being worked on, in the user's words: an account name, a wallet,
  /// a card. Never an id.
  final String? subject;

  /// Which subject of how many, counting from one.
  ///
  /// [subjectCount] stays null while the source is still discovering
  /// subjects, so 'Account 2 of 5' never appears before the 5 is true.
  final int? subjectIndex;
  final int? subjectCount;

  /// The booking dates the request in flight covers.
  ///
  /// For sources that walk history in chunks - PayPal caps a request at 31
  /// days, FinTS is usually asked one range at a time - this is the chunk.
  /// For comdirect, where one request covers a whole account, it is that.
  final DownloadRange? window;

  /// Items dealt with so far, and how many there are in this phase.
  final int? done;
  final int? total;

  const DownloadProgress._(
    this.phase, {
    this.subject,
    this.subjectIndex,
    this.subjectCount,
    this.window,
    this.done,
    this.total,
  });

  /// Asking the source which accounts it has.
  const DownloadProgress.findingAccounts({int? done, int? total})
    : this._(DownloadPhase.findingAccounts, done: done, total: total);

  /// Pulling transactions for one account.
  const DownloadProgress.fetching({
    String? subject,
    int? subjectIndex,
    int? subjectCount,
    DownloadRange? window,
    int? done,
    int? total,
  }) : this._(
         DownloadPhase.fetching,
         subject: subject,
         subjectIndex: subjectIndex,
         subjectCount: subjectCount,
         window: window,
         done: done,
         total: total,
       );

  /// Writing what arrived.
  const DownloadProgress.saving({String? subject, int? done, int? total})
    : this._(DownloadPhase.saving, subject: subject, done: done, total: total);

  /// Pairing what arrived with the tags the user already uses.
  const DownloadProgress.matching({int? done, int? total})
    : this._(DownloadPhase.matching, done: done, total: total);

  /// Equality is what lets [DownloadProgressSink] drop repeats, so it covers
  /// every field: two reports that differ anywhere are two different things
  /// to say.
  @override
  bool operator ==(Object other) =>
      other is DownloadProgress &&
      other.phase == phase &&
      other.subject == subject &&
      other.subjectIndex == subjectIndex &&
      other.subjectCount == subjectCount &&
      other.window == window &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(
    phase,
    subject,
    subjectIndex,
    subjectCount,
    window,
    done,
    total,
  );
}

/// Lets a running download say what it is doing, without knowing who asks.
///
/// The sibling of [DownloadCancellation]. That one carries a question down
/// into the loops that make a download long; this one carries the answer back
/// up. Both are objects rather than bare closures because both come with a
/// rule that has to travel with them.
///
/// The rule here is that reporting is cheap and lossy. Call [report] as often
/// as is convenient - once per turnover in a loop of thousands is fine, and
/// the auto-match loop is exactly that. Reports that do not change the phase
/// are coalesced to at most one per [minInterval].
///
/// A change of [DownloadProgress.phase] always gets through, and that is what
/// makes the coalescing safe: every phase is followed by another phase or by
/// the end of the run, so a held-back report is always superseded within one
/// step. No stale number is ever the last thing left on screen, and nothing
/// needs flushing.
class DownloadProgressSink {
  /// How often an unchanged phase may repaint.
  ///
  /// Slow enough that a tight loop cannot flood a cubit whose states have no
  /// equality, fast enough that a number still looks alive.
  final Duration minInterval;

  final void Function(DownloadProgress progress)? _onReport;

  DownloadProgress? _sent;
  DateTime? _sentAt;

  DownloadProgressSink(
    void Function(DownloadProgress progress) onReport, {
    this.minInterval = const Duration(milliseconds: 250),
  }) : _onReport = onReport;

  /// A sink for a run nobody is watching.
  ///
  /// Exists so that no ingestor has to write `progress?.report(...)`, and so
  /// no test exercises a null branch that production never takes.
  DownloadProgressSink.discard()
    : minInterval = Duration.zero,
      _onReport = null;

  /// Says what the download is doing, if anyone is listening and enough has
  /// changed to be worth saying.
  void report(DownloadProgress progress) {
    final onReport = _onReport;
    if (onReport == null) return;
    if (progress == _sent) return;

    final sentAt = _sentAt;
    final isPhaseChange = progress.phase != _sent?.phase;
    final isDue =
        sentAt == null || DateTime.now().difference(sentAt) >= minInterval;
    if (!isPhaseChange && !isDue) return;

    _sent = progress;
    _sentAt = DateTime.now();
    onReport(progress);
  }
}

/// The two lines the sheet shows for [progress].
///
/// Two rather than one because they move at different speeds: the title says
/// what is happening and holds still, the detail carries the numbers. Merged,
/// the whole line would jitter on every update.
///
/// A null [progress] is the honest state before the first report, and for any
/// source that reports nothing at all. It gives back exactly the sentence the
/// sheet showed before there was a backchannel.
({String title, String? detail}) downloadProgressText(
  DownloadProgress? progress,
) {
  if (progress == null) {
    return (title: 'Downloading transactions…', detail: null);
  }
  return (title: _title(progress), detail: _detail(progress));
}

String _title(DownloadProgress it) => switch (it.phase) {
  DownloadPhase.findingAccounts => 'Looking for your accounts…',
  DownloadPhase.fetching => switch (it.subject) {
    final subject? => 'Downloading $subject…',
    null => 'Downloading transactions…',
  },
  DownloadPhase.saving => 'Saving what arrived…',
  DownloadPhase.matching => 'Matching them to your tags…',
};

/// The numbers under the title, and only the ones that are true.
String? _detail(DownloadProgress it) {
  final parts = <String>[
    if (_subjectPart(it) case final part?) part,
    if (_countPart(it) case final part?) part,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Where the download is in a list of accounts, once both numbers are true.
///
/// Suppressed for a single account: 'Account 1 of 1' is the common case, and
/// it says nothing the title above it does not.
String? _subjectPart(DownloadProgress it) {
  final index = it.subjectIndex;
  final count = it.subjectCount;
  if (index == null || count == null || count < 2) return null;
  return 'Account $index of $count';
}

String? _countPart(DownloadProgress it) => switch (it.phase) {
  DownloadPhase.findingAccounts => _counted(it, 'accounts'),
  DownloadPhase.fetching => _counted(it, 'transactions'),
  DownloadPhase.saving => switch (it.total) {
    final total? => '$total transactions',
    null => null,
  },
  DownloadPhase.matching => switch (it.total) {
    final total? => '${it.done ?? 0} of $total matched',
    null => null,
  },
};

/// '12 of 40 transactions', or '12 transactions so far' while the source is
/// still counting.
///
/// Nothing at all before the first one arrives: a zero says less than the
/// title above it already does.
String? _counted(DownloadProgress it, String noun) {
  final done = it.done;
  if (done == null || done == 0) return null;
  final total = it.total;
  return total == null ? '$done $noun so far' : '$done of $total $noun';
}
