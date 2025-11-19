import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/tag_suggestion.freezed.dart';
part '../../_gen/turnover/model/tag_suggestion.g.dart';

/// Confidence level for a tag suggestion.
enum SuggestionConfidence {
  /// High confidence (score >= 0.7)
  high,

  /// Medium confidence (0.4 <= score < 0.7)
  medium,

  /// Low confidence (score < 0.4)
  low;

  /// Returns the number of filled dots to display (1-3).
  int get dotCount {
    return switch (this) {
      SuggestionConfidence.high => 3,
      SuggestionConfidence.medium => 2,
      SuggestionConfidence.low => 1,
    };
  }

  /// Creates a confidence level from a score (0.0 to 1.0).
  static SuggestionConfidence fromScore(double score) {
    if (score >= 0.7) return SuggestionConfidence.high;
    if (score >= 0.4) return SuggestionConfidence.medium;
    return SuggestionConfidence.low;
  }
}

/// Represents a tag suggestion with confidence score and suggested amount.
@freezed
abstract class TagSuggestion with _$TagSuggestion {
  const TagSuggestion._();

  const factory TagSuggestion({
    /// The suggested tag.
    required Tag tag,

    /// Confidence score (0.0 to 1.0).
    required double score,

    /// Currency unit for the suggested amount.
    required String amountUnit,
  }) = _TagSuggestion;

  factory TagSuggestion.fromJson(Map<String, dynamic> json) =>
      _$TagSuggestionFromJson(json);

  /// Returns the confidence level based on the score.
  SuggestionConfidence get confidence =>
      SuggestionConfidence.fromScore(score);
}
