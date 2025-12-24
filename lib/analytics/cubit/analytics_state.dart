import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/analytics/cubit/analytics_state.freezed.dart';
part '../../_gen/analytics/cubit/analytics_state.g.dart';

@freezed
abstract class AnalyticsState with _$AnalyticsState {
  const factory AnalyticsState({
    @Default(Status.initial) Status status,

    // ignore: invalid_annotation_target
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<Tag> allTags,

    // ignore: invalid_annotation_target
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<UuidValue> selectedTagIds,

    // ignore: invalid_annotation_target
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default({})
    Map<String, List<TagSummary>> dataSummaries,

    required DateTime startDate,
    required DateTime endDate,

    String? errorMessage,
  }) = _AnalyticsState;

  factory AnalyticsState.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsStateFromJson(json);
}
