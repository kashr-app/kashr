import 'package:decimal/decimal.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/home/model/tag_prediction.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/home/cubit/dashboard_state.freezed.dart';

@freezed
abstract class DashboardState with _$DashboardState {
  const factory DashboardState({
    required Status status,
    required Status bankDownloadStatus,
    required Period period,
    required Decimal totalIncome,
    required Decimal totalExpenses,
    required Decimal totalTransfers,
    required Decimal unallocatedIncome,
    required Decimal unallocatedExpenses,
    required int pendingCount,
    required Decimal pendingTotalAmount,
    required int tagTurnoverCount,

    required List<TagSummary> incomeTagSummaries,
    required List<TagSummary> expenseTagSummaries,
    required List<TagSummary> transferTagSummaries,

    required Map<TurnoverSign, Map<UuidValue, TagPrediction>> predictionByTagId,

    required TurnoverWithTagTurnovers? firstUnallocatedTurnover,
    required int unallocatedCountInPeriod,
    required int unallocatedCountTotal,
    required Decimal unallocatedSumTotal,

    required int transfersNeedingReviewCount,

    String? errorMessage,
  }) = _DashboardState;
}
