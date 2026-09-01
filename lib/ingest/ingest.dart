import 'package:kashr/ingest/download_range.dart';
import 'package:uuid/uuid.dart';

/// Asks a download to stop, without being able to abort what is in flight.
///
/// Nothing here cancels an HTTP request. The loops that make a download long
/// check this between steps instead, so stopping costs one request rather
/// than the rest of the run.
///
/// Stopping needs no rollback. A download cursor only moves once a run
/// finished, so a stopped run leaves nothing that claims to be complete, and
/// the next download fetches the same window again.
class DownloadCancellation {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  /// Throws [DownloadCancelledException] once [cancel] was called.
  ///
  /// Belongs at the points where stopping is safe: before fetching the next
  /// piece, never between writing what was fetched and the bookkeeping that
  /// makes it consistent.
  void throwIfCancelled() {
    if (_isCancelled) throw const DownloadCancelledException();
  }
}

/// Unwinds a download that the user stopped.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'The download was cancelled.';
}

/// A source that can pull bank data into the app.
abstract class DataIngestor {
  /// Downloads everything [request] covers.
  ///
  /// The per-account booking date ranges are derived from the accounts' own
  /// download cursors, see [DownloadRequest].
  ///
  /// A successful result means every account in
  /// [DataIngestResult.downloadedAccountIds] is complete through
  /// [DownloadRequest.endInclusive]. Moving the download cursors there is
  /// the caller's job, it is the same for every bank.
  ///
  /// Throws [DownloadCancelledException] when [cancellation] was cancelled,
  /// which implementations check only where stopping is safe.
  Future<DataIngestResult> ingest(
    DownloadRequest request,
    DownloadCancellation cancellation,
  );
}

class DataIngestResult {
  final ResultStatus status;
  final String? errorMessage;
  final int newCount;
  final int updatedCount;
  final int autoMatchedCount;
  final int unmatchedCount;

  /// The accounts this run actually fetched transactions for.
  ///
  /// Includes accounts that were only discovered during the run. Empty unless
  /// the run succeeded.
  final List<UuidValue> downloadedAccountIds;

  const DataIngestResult._({
    required this.status,
    this.errorMessage,
    required this.newCount,
    required this.updatedCount,
    required this.autoMatchedCount,
    required this.unmatchedCount,
    required this.downloadedAccountIds,
  });

  const DataIngestResult.success({
    required int newCount,
    required int updatedCount,
    required int autoMatchedCount,
    required int unmatchedCount,
    required List<UuidValue> downloadedAccountIds,
  }) : this._(
         status: ResultStatus.success,
         newCount: newCount,
         updatedCount: updatedCount,
         autoMatchedCount: autoMatchedCount,
         unmatchedCount: unmatchedCount,
         downloadedAccountIds: downloadedAccountIds,
       );

  const DataIngestResult.error(ResultStatus status, {String? errorMessage})
    : this._(
        status: status,
        errorMessage: errorMessage,
        newCount: 0,
        updatedCount: 0,
        autoMatchedCount: 0,
        unmatchedCount: 0,
        downloadedAccountIds: const [],
      );
}

enum ResultStatus { success, unauthed, otherError }

/// Why a download stopped, in terms the user can act on.
///
/// The sheet picks the way out from this, not from the message: only the
/// reason knows whether trying the same thing again could ever work.
enum DownloadFailureReason {
  /// The bank rejected the stored credentials.
  badCredentials,

  /// The device could not reach the bank.
  network,

  /// The bank answered, but could not serve the request.
  bankUnavailable,

  /// The confirmation in the banking app never arrived.
  confirmationTimeout,

  /// Anything the app cannot tell apart.
  unknown,
}
