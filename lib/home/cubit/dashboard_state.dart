import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/home/cubit/dashboard_state.freezed.dart';
part '../../_gen/home/cubit/dashboard_state.g.dart';

@freezed
abstract class DashboardState with _$DashboardState {
  const factory DashboardState({
    @Default(Status.initial) Status status,
    required int selectedYear,
    required int selectedMonth,
    required Decimal totalIncome,
    required Decimal totalExpenses,
    required Decimal unallocatedIncome,
    required Decimal unallocatedExpenses,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<TagSummary> incomeTagSummaries,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<TagSummary> expenseTagSummaries,
    String? errorMessage,
  }) = _DashboardState;

  factory DashboardState.fromJson(Map<String, dynamic> json) =>
      _$DashboardStateFromJson(json);
}
