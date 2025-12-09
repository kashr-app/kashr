abstract class DataIngestor {
  Future<DataIngestResult> ingest({
    required DateTime minBookingDate,
    required DateTime maxBookingDate,
  });
}

class DataIngestResult {
  ResultStatus status;
  String? errorMessage;
  int autoMatchedCount;
  int unmatchedCount;
  DataIngestResult({
    required this.status,
    this.errorMessage,
    this.autoMatchedCount = 0,
    this.unmatchedCount = 0,
  });
}

enum ResultStatus { success, unauthed, otherError }
