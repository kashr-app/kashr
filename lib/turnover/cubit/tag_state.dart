import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/cubit/tag_state.freezed.dart';
part '../../_gen/turnover/cubit/tag_state.g.dart';

@freezed
abstract class TagState with _$TagState {
  const factory TagState({
    @Default(Status.initial) Status status,
    @Default([]) List<Tag> tags,
    String? errorMessage,
  }) = _TagState;

  factory TagState.fromJson(Map<String, dynamic> json) =>
      _$TagStateFromJson(json);
}
