import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/turnover_with_tag_turnovers.freezed.dart';
part '../../_gen/turnover/model/turnover_with_tag_turnovers.g.dart';

/// A data class that combines a turnover with its associated tags and amounts.
@freezed
abstract class TurnoverWithTagTurnovers with _$TurnoverWithTagTurnovers {
  const factory TurnoverWithTagTurnovers({
    required Turnover turnover,
    required List<TagTurnover> tagTurnovers,
  }) = _TurnoverWithTagTurnovers;

  factory TurnoverWithTagTurnovers.fromJson(Map<String, dynamic> json) =>
      _$TurnoverWithTagTurnoversFromJson(json);
}
