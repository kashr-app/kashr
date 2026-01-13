import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/dashboard/model/tag_prediction.freezed.dart';

/// Prediction for a tag's spending based on historical data.
@freezed
abstract class TagPrediction with _$TagPrediction {
  const factory TagPrediction({
    /// Historical average amount for this tag.
    required Decimal averageFromHistory,

    /// Number of historical periods analyzed (e.g., 3 for last 3 months).
    required int periodsAnalyzed,
  }) = _TagPrediction;
}
