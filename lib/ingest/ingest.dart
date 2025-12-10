abstract class DataIngestor {
  Future<DataIngestResult> ingest({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  });
}

class DataIngestResult {
  final ResultStatus status;
  final String? errorMessage;
  final int newCount;
  final int updatedCount;
  final int autoMatchedCount;
  final int unmatchedCount;
  const DataIngestResult._({
    required this.status,
    this.errorMessage,
    required this.newCount,
    required this.updatedCount,
    required this.autoMatchedCount,
    required this.unmatchedCount,
  });

  const DataIngestResult.success({
    required int newCount,
    required int updatedCount,
    required int autoMatchedCount,
    required int unmatchedCount,
  }) : this._(
         status: ResultStatus.success,
         newCount: newCount,
         updatedCount: updatedCount,
         autoMatchedCount: autoMatchedCount,
         unmatchedCount: unmatchedCount,
       );

  const DataIngestResult.error(ResultStatus status, {String? errorMessage})
    : this._(
        status: status,
        errorMessage: errorMessage,
        newCount: 0,
        updatedCount: 0,
        autoMatchedCount: 0,
        unmatchedCount: 0,
      );
}

enum ResultStatus { success, unauthed, otherError }
