import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/model/booking_date.dart';

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
BookingDate minBookingDateFor(
  Account account, {
  required DownloadRequest request,
  required BookingDate? startDateWithoutCursor,
}) {
  if (request.ignoreCursors) return request.startDate;

  final cursor = account.downloadCursorDate;
  if (cursor != null) {
    return cursor.addDays(-downloadOverlapDays);
  }
  return startDateWithoutCursor ?? request.startDate;
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
  final startDateWithoutCursor = oldestDownloadCursor(accounts);

  BookingDate? min;
  for (final account in downloadableAccounts(accounts)) {
    final accountMin = minBookingDateFor(
      account,
      request: request,
      startDateWithoutCursor: startDateWithoutCursor,
    );
    if (min == null || accountMin.isBefore(min)) min = accountMin;
  }
  return DownloadRange(
    min: min ?? request.startDate,
    max: request.maxBookingDate,
  );
}

/// An inclusive range of booking dates.
class DownloadRange {
  final BookingDate min;
  final BookingDate max;

  const DownloadRange({required this.min, required this.max});
}

/// The scope of one download run.
class DownloadRequest {
  /// Oldest booking date to fetch for accounts that have never been
  /// downloaded.
  ///
  /// Accounts with an [Account.downloadCursorDate] start at that cursor minus
  /// [downloadOverlapDays] instead, unless [ignoreCursors] is set.
  final BookingDate startDate;

  /// Newest booking date to fetch, inclusive. Normally today.
  final BookingDate maxBookingDate;

  /// Fetches every account from [startDate], ignoring the cursors.
  ///
  /// Set when the user widened the range by hand.
  final bool ignoreCursors;

  const DownloadRequest({
    required this.startDate,
    required this.maxBookingDate,
    this.ignoreCursors = false,
  });

  /// A run that catches every account up to [today].
  factory DownloadRequest.upTo(
    BookingDate today, {
    required BookingDate startDate,
    bool ignoreCursors = false,
  }) => DownloadRequest.between(
    startDate: startDate,
    endDate: today,
    ignoreCursors: ignoreCursors,
  );

  /// A run over the booking dates the user picked, both ends inclusive.
  ///
  /// The end may lie in the past, which is the whole point of picking it:
  /// filling a gap in the history does not have to fetch everything since.
  factory DownloadRequest.between({
    required BookingDate startDate,
    required BookingDate endDate,
    bool ignoreCursors = false,
  }) => DownloadRequest(
    startDate: startDate,
    maxBookingDate: endDate,
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

  /// The start date to request, relative to [today].
  ///
  /// For [everything] the bank decides where the data really starts; the
  /// cursor then ends up wherever that is.
  BookingDate startDate(BookingDate today) {
    final months = this.months;
    if (months == null) return BookingDate(2000, 1, 1);
    return BookingDate(today.year, today.month - months, today.day);
  }
}
