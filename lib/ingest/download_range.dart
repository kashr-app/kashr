import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/model/period.dart';

/// How far back before the download cursor to re-fetch on every download.
///
/// Banks amend bookings after the fact, and a transaction can appear days
/// after its booking date, so the cursor alone would miss it. The overlap
/// is close to free: `upsertTurnovers` compares content and writes nothing
/// for an unchanged transaction, and the extra rows rarely add a page at a
/// page size of 50.
///
/// Erring long is deliberate. A missed transaction does not show up as a
/// balance mismatch, because `_reconcileBalances` absorbs the difference
/// into the opening balance — so the loss is silent and permanent.
const downloadOverlapDays = 14;

/// How old the oldest download cursor may get before the download button
/// starts pointing out that the data is behind.
///
/// Purely a data freshness signal.
const downloadStaleAfterDays = 3;

/// The accounts a download can fetch data for.
Iterable<Account> downloadableAccounts(Iterable<Account> accounts) => accounts
    .where((it) => it.syncSource != null && it.syncSource != SyncSource.manual);

/// Whether this would be the first download ever.
///
/// True when no downloadable account has a cursor to anchor to, which also
/// covers the case that no account exists yet: accounts are discovered during
/// the download itself.
bool isFirstDownload(Iterable<Account> accounts) =>
    downloadableAccounts(accounts).every((it) => it.downloadCursorDate == null);

/// Whether the downloaded data is behind by more than
/// [downloadStaleAfterDays].
///
/// Accounts that were never downloaded count as stale. Without any
/// downloadable account there is nothing to be behind on.
bool isDownloadStale(Iterable<Account> accounts, {BookingDate? today}) {
  final relevant = downloadableAccounts(accounts).toList();
  if (relevant.isEmpty) return false;

  final threshold = (today ?? BookingDate.today()).addDays(
    -downloadStaleAfterDays,
  );
  return relevant.any(
    (it) =>
        it.downloadCursorDate == null ||
        it.downloadCursorDate!.isBefore(threshold),
  );
}

/// The booking dates one download run covers for a single account.
///
/// Every account is fetched from its own cursor, so accounts that were added
/// or downloaded at different times each catch up on exactly what they miss.
BookingDate startInclusiveFor(
  Account account, {
  required DownloadRequest request,
  required BookingDate? startInclusiveWithoutCursor,
}) {
  if (request.ignoreCursors) return request.startInclusive;

  final cursor = account.downloadCursorDate;
  if (cursor != null) {
    return cursor.addDays(-downloadOverlapDays);
  }
  return startInclusiveWithoutCursor ?? request.startInclusive;
}

/// The oldest download cursor across [accounts].
///
/// `null` when no account was ever downloaded.
BookingDate? oldestDownloadCursor(Iterable<Account> accounts) {
  BookingDate? oldest;
  for (final account in downloadableAccounts(accounts)) {
    final cursor = account.downloadCursorDate;
    if (cursor == null) continue;
    if (oldest == null || cursor.isBefore(oldest)) oldest = cursor;
  }
  return oldest;
}

/// The single range shown to the user: the oldest effective start across all
/// accounts up to the requested end.
///
/// Per-account ranges are an internal detail and never change the result.
DownloadRange unionDownloadRange(
  Iterable<Account> accounts, {
  required DownloadRequest request,
}) {
  final startInclusiveWithoutCursor = oldestDownloadCursor(accounts);

  BookingDate? earliest;
  for (final account in downloadableAccounts(accounts)) {
    final accountStart = startInclusiveFor(
      account,
      request: request,
      startInclusiveWithoutCursor: startInclusiveWithoutCursor,
    );
    if (earliest == null || accountStart.isBefore(earliest)) {
      earliest = accountStart;
    }
  }
  return DownloadRange(
    startInclusive: earliest ?? request.startInclusive,
    endInclusive: request.endInclusive,
  );
}

/// The booking dates a download of [period] covers.
///
/// Null when [period] has not begun yet. There is nothing to ask a bank for,
/// and offering the download would only produce an empty one.
///
/// The end is clamped to [today] because no bank books the future, and
/// asking for it would move the download cursors past the data that exists.
DownloadRange? periodDownloadRange(Period period, {BookingDate? today}) {
  final lastFetchableDay = today ?? BookingDate.today();
  if (period.startInclusive.isAfter(lastFetchableDay)) return null;

  final lastDay = period.endExclusive.addDays(-1);
  return DownloadRange(
    startInclusive: period.startInclusive,
    endInclusive: lastDay.isAfter(lastFetchableDay)
        ? lastFetchableDay
        : lastDay,
  );
}

/// A range of booking dates that includes both of its ends.
///
/// The exception to the half-open rule in `doc/README.md`, because the bank
/// defines it that way and the user picks both edges by hand.
class DownloadRange {
  final BookingDate startInclusive;
  final BookingDate endInclusive;

  const DownloadRange({
    required this.startInclusive,
    required this.endInclusive,
  });
}

/// The scope of one download run.
class DownloadRequest {
  /// Oldest booking date to fetch for accounts that have never been
  /// downloaded.
  ///
  /// Accounts with an [Account.downloadCursorDate] start at that cursor minus
  /// [downloadOverlapDays] instead, unless [ignoreCursors] is set.
  final BookingDate startInclusive;

  /// Newest booking date to fetch. Normally today.
  final BookingDate endInclusive;

  /// Fetches every account from [startInclusive], ignoring the cursors.
  ///
  /// Set when the user widened the range by hand.
  final bool ignoreCursors;

  const DownloadRequest({
    required this.startInclusive,
    required this.endInclusive,
    this.ignoreCursors = false,
  });

  /// A run that catches every account up to [endInclusive].
  factory DownloadRequest.upTo({
    required BookingDate endInclusive,
    required BookingDate startInclusive,
    bool ignoreCursors = false,
  }) => DownloadRequest.between(
    startInclusive: startInclusive,
    endInclusive: endInclusive,
    ignoreCursors: ignoreCursors,
  );

  /// A run over the booking dates the user picked.
  ///
  /// The end may lie in the past, which is the whole point of picking it:
  /// filling a gap in the history does not have to fetch everything since.
  factory DownloadRequest.between({
    required BookingDate startInclusive,
    required BookingDate endInclusive,
    bool ignoreCursors = false,
  }) => DownloadRequest(
    startInclusive: startInclusive,
    endInclusive: endInclusive,
    ignoreCursors: ignoreCursors,
  );
}

/// How far back the very first download reaches.
///
/// Only asked once, because afterwards the cursor answers the question.
enum DownloadDepth {
  threeMonths('Last 3 months', 3),
  twelveMonths('Last 12 months', 12),
  everything('As far back as the bank provides', null);

  const DownloadDepth(this.label, this.months);

  final String label;

  /// `null` asks for more history than any bank is likely to keep.
  final int? months;

  /// The oldest booking date to request, relative to [today].
  ///
  /// For [everything] the bank decides where the data really starts; the
  /// cursor then ends up wherever that is.
  BookingDate startInclusive(BookingDate today) {
    final months = this.months;
    if (months == null) return BookingDate(2000, 1, 1);
    return BookingDate(today.year, today.month - months, today.day);
  }
}
