import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/cubit/turnover_state.freezed.dart';
part '../../_gen/turnover/cubit/turnover_state.g.dart';

@freezed
abstract class TurnoverState with _$TurnoverState {
  const factory TurnoverState({
    required Status status,
    required List<Turnover> turnovers,
    String? errorMessage,
  }) = _TurnoverState;

  factory TurnoverState.fromJson(Map<String, dynamic> json) =>
      _$TurnoverStateFromJson(json);
}
