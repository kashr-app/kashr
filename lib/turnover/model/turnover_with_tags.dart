import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/turnover_with_tags.freezed.dart';
part '../../_gen/turnover/model/turnover_with_tags.g.dart';

/// A data class that combines a turnover with its associated tags and amounts.
/// This avoids the N+1 query problem by loading all data in one efficient query.
@freezed
abstract class TurnoverWithTags with _$TurnoverWithTags {
  const factory TurnoverWithTags({
    required Turnover turnover,
    required List<TagTurnoverWithTag> tagTurnovers,
  }) = _TurnoverWithTags;

  factory TurnoverWithTags.fromJson(Map<String, dynamic> json) =>
      _$TurnoverWithTagsFromJson(json);
}

/// Combines a TagTurnover with its associated Tag for efficient display.
@freezed
abstract class TagTurnoverWithTag with _$TagTurnoverWithTag {
  const factory TagTurnoverWithTag({
    required TagTurnover tagTurnover,
    required Tag tag,
  }) = _TagTurnoverWithTag;

  factory TagTurnoverWithTag.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverWithTagFromJson(json);
}
