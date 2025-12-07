import 'package:finanalyzer/turnover/model/turnover.dart';

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
  List<Turnover> unmatchedTurnovers;
  DataIngestResult({
    required this.status,
    this.errorMessage,
    this.autoMatchedCount = 0,
    this.unmatchedTurnovers = const [],
  });
}

enum ResultStatus { success, unauthed, otherError }
