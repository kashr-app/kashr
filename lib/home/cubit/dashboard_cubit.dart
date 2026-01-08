import 'dart:async';

import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/home/cubit/dashboard_state.dart';
import 'package:kashr/home/model/tag_prediction.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_change.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_change.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing the dashboard state.
///
/// Automatically refreshes when underlying data changes in repositories.
class DashboardCubit extends Cubit<DashboardState> {
  final TurnoverRepository _turnoverRepository;
  final TurnoverService _turnoverService;
  final TagTurnoverRepository _tagTurnoverRepository;
  final TagRepository _tagRepository;
  final TransferRepository _transferRepository;
  final Logger log;

  StreamSubscription<dynamic>? _changeSubscription;
  StreamSubscription<TurnoverChange>? _turnoverSubscription;
  StreamSubscription<TagTurnoverChange>? _tagTurnoverSubscription;
  StreamSubscription<List<Tag>?>? _tagsSubscription;
  StreamSubscription<TransferChange?>? _transferSubscription;

  DashboardCubit(
    this._turnoverRepository,
    this._turnoverService,
    this._tagTurnoverRepository,
    this._tagRepository,
    this._transferRepository,
    this.log,
  ) : super(
        DashboardState(
          status: Status.initial,
          bankDownloadStatus: Status.initial,
          period: Period.now(PeriodType.month),
          totalIncome: Decimal.zero,
          totalExpenses: Decimal.zero,
          totalTransfers: Decimal.zero,
          unallocatedIncome: Decimal.zero,
          unallocatedExpenses: Decimal.zero,
          firstUnallocatedTurnover: null,
          incomeTagSummaries: [],
          expenseTagSummaries: [],
          transferTagSummaries: [],
          predictionByTagId: {},
          unallocatedCountInPeriod: 0,
          unallocatedCountTotal: 0,
          unallocatedSumTotal: Decimal.zero,
          pendingCount: 0,
          pendingTotalAmount: Decimal.zero,
          transfersNeedingReviewCount: 0,
          tagTurnoverCount: 0,
        ),
      ) {
    _setupSubscriptions();
  }

  /// Sets up subscriptions to all repository changes.
  void _setupSubscriptions() {
    _turnoverSubscription = _turnoverRepository.watchChanges().listen(
      _onTurnoverChanged,
    );
    _tagTurnoverSubscription = _tagTurnoverRepository.watchChanges().listen(
      _onTagTurnoverChanged,
    );
    _tagsSubscription = _tagRepository.watchTags().listen(_onTagsChanged);
    _transferSubscription = _transferRepository.watchChanges().listen(
      _onTransferChanged,
    );
  }

  void _onTurnoverChanged(TurnoverChange change) {
    final shouldRefresh = switch (change) {
      TurnoversInserted(:final turnovers) => turnovers.any(
        _affectsSelectedPeriod,
      ),
      TurnoversUpdated(:final turnovers) => turnovers.any(
        _affectsSelectedPeriod,
      ),
      TurnoversDeleted() => true, // Conservative: always refresh on deletes
    };

    if (shouldRefresh) {
      loadPeriodData();
    }
  }

  void _onTagTurnoverChanged(TagTurnoverChange change) {
    final shouldRefresh = switch (change) {
      TagTurnoversInserted(:final tagTurnovers) => tagTurnovers.any(
        (tt) => _bookingDateInPeriod(tt.bookingDate),
      ),
      TagTurnoversUpdated(:final tagTurnovers) => tagTurnovers.any(
        (tt) => _bookingDateInPeriod(tt.bookingDate),
      ),
      TagTurnoversDeleted() => true, // Conservative: always refresh on deletes
    };

    if (shouldRefresh) {
      loadPeriodData();
    }
  }

  void _onTagsChanged(List<Tag>? tags) {
    final shouldRefresh = true;
    if (shouldRefresh) {
      loadPeriodData();
    }
  }

  void _onTransferChanged(TransferChange change) {
    loadPeriodData();
  }

  /// Checks if a turnover affects the currently selected period.
  bool _affectsSelectedPeriod(Turnover turnover) {
    final bookingDate = turnover.bookingDate;
    return bookingDate != null && _bookingDateInPeriod(bookingDate);
  }

  /// Checks if a booking date falls within the selected period.
  bool _bookingDateInPeriod(DateTime date) {
    return state.period.contains(date);
  }

  @override
  Future<void> close() {
    _changeSubscription?.cancel();
    _turnoverSubscription?.cancel();
    _tagTurnoverSubscription?.cancel();
    _tagsSubscription?.cancel();
    _transferSubscription?.cancel();
    return super.close();
  }

  Future<DataIngestResult> ingestData(DataIngestor ingestor) async {
    void setBankDownloadStatus(Status status) {
      emit(state.copyWith(bankDownloadStatus: status));
    }

    setBankDownloadStatus(Status.loading);

    final result = await ingestor.ingest(state.period);

    switch (result.status) {
      case ResultStatus.success:
        setBankDownloadStatus(Status.success);
        unawaited(loadPeriodData());
      case ResultStatus.unauthed:
        setBankDownloadStatus(Status.initial);
      case ResultStatus.otherError:
        setBankDownloadStatus(Status.error);
    }
    return result;
  }

  /// Loads data that does not depend on the selected period.
  Future<void> _loadNonPeriodData() async {
    // Run all queries in parallel with type-safe record destructuring
    final (
      unallocatedCountTotal,
      unallocatedSumTotal,
      (pendingCount, pendingTotalAmount),
      transfersNeedingReviewCount,
    ) = await (
      _turnoverRepository.countUnallocatedTurnovers(),
      _turnoverRepository.sumUnallocatedTurnovers(),
      _pending(),
      _transferRepository.countTransfersNeedingReview(),
    ).wait;

    emit(
      state.copyWith(
        unallocatedCountTotal: unallocatedCountTotal,
        unallocatedSumTotal: unallocatedSumTotal,
        pendingCount: pendingCount,
        pendingTotalAmount: pendingTotalAmount,
        transfersNeedingReviewCount: transfersNeedingReviewCount,
      ),
    );
  }

  /// Loads cashflow data for the currently selected period.
  ///
  /// If [invalidateNonPeriodData] is false the hint data is not reloaded.
  /// This is particularly important as the metadata can be expensive
  /// and does not change, e.g. when switching period.
  Future<void> loadPeriodData({bool invalidateNonPeriodData = true}) async {
    emit(state.copyWith(status: Status.loading));

    try {
      // Load non-period data separately if needed
      if (invalidateNonPeriodData) {
        await _loadNonPeriodData();
      }

      final period = state.period;
      // Run all independent queries in parallel with type-safe record destructuring
      final (
        tags,
        turnovers,
        tagTurnoverCount,
        incomeTagSummaries,
        expenseTagSummaries,
        (transferTagSummaries, totalTransfers),
        firstUnallocatedTurnovers,
        unallocatedCountInPeriod,
        ttData,
      ) = await (
        _tagRepository.getAllTagsCached(),
        _turnoverRepository.getTurnoversForPeriod(period),
        _tagTurnoverRepository.count(period),
        _tagTurnoverRepository.getTagSummariesForPeriod(
          period,
          TurnoverSign.income,
          semantic: null,
        ),
        _tagTurnoverRepository.getTagSummariesForPeriod(
          period,
          TurnoverSign.expense,
          semantic: null,
        ),
        _loadTransfersSummary(period),
        _turnoverRepository.getUnallocatedTurnoversForPeriod(period, limit: 1),
        _turnoverRepository.countUnallocatedTurnovers(period: period),
        _tagTurnoverRepository.getTagTurnoversPeriodAllocation(period),
      ).wait;

      // Calculate predictions separately (can run in parallel with the above)
      final predictionByTagId = await _calculatePredictionByTagId(period);

      final tagById = tags.associateBy((it) => it.id);

      // Get first unallocated turnover with tags (depends on query above)
      final firstUnallocatedTurnover =
          (await _turnoverService.getTurnoversWithTags(
            firstUnallocatedTurnovers,
          )).firstOrNull;

      // Calculate total income/expense using tag booking dates + untagged portions

      // 1. Sum from tag turnovers allocated in this period (by tt.booking_date)
      final totalAbsTTByType = ttData.allocatedInPeriod
          .groupFoldBy<TurnoverType, Decimal>(
            (it) => (tagById[it.tagId]?.isTransfer ?? false)
                ? TurnoverType.transfer
                : it.amountValue < Decimal.zero
                ? TurnoverType.expense
                : TurnoverType.income,
            (sum, tt) => (sum ?? Decimal.zero) + tt.amountValue.abs(),
          );
      // turnovers are counted twice (once per account), so we need to divide the total by 2
      totalAbsTTByType[TurnoverType.transfer] =
          ((totalAbsTTByType[TurnoverType.transfer] ?? Decimal.zero) /
                  Decimal.fromInt(2))
              .toDecimal(scaleOnInfinitePrecision: 2);

      // 2. Calculate untagged portions of turnovers in this period
      // Build map of tagged amounts per turnover
      final ttByTurnoverId = [
        ...ttData.allocatedInPeriod,
        ...ttData.allocatedOutsidePeriodButTurnoverInPeriod,
      ].groupListsBy((it) => it.turnoverId);

      final taggedAmountByTurnover = <UuidValue, Decimal>{};
      final totalAbsUntaggedBySign = <TurnoverSign, Decimal>{};
      for (final turnover in turnovers) {
        final turnoverId = turnover.id;
        final taggedAmount =
            ttByTurnoverId[turnoverId]?.fold(
              Decimal.zero,
              (sum, it) => sum + it.amountValue,
            ) ??
            Decimal.zero;
        final untaggedAmount = turnover.amountValue - taggedAmount;
        taggedAmountByTurnover[turnoverId] = taggedAmount;
        final sign = TurnoverSign.fromDecimal(turnover.amountValue);
        totalAbsUntaggedBySign[sign] =
            (totalAbsUntaggedBySign[sign] ?? Decimal.zero) +
            untaggedAmount.abs();
      }

      // Total = tagged (by tt.booking_date) + untagged (by tv.booking_date)
      final totalAllIncomeAbs =
          (totalAbsTTByType[TurnoverType.income] ?? Decimal.zero) +
          (totalAbsUntaggedBySign[TurnoverSign.income] ?? Decimal.zero);
      final totalAllExpensesAbs =
          (totalAbsTTByType[TurnoverType.expense] ?? Decimal.zero) +
          (totalAbsUntaggedBySign[TurnoverSign.expense] ?? Decimal.zero);

      final unallocatedIncome =
          totalAbsUntaggedBySign[TurnoverSign.income] ?? Decimal.zero;
      final unallocatedExpenses =
          totalAbsUntaggedBySign[TurnoverSign.expense] ?? Decimal.zero;

      // Total income/expenses for cashflow = allocated + unallocated
      final totalIncome = totalAllIncomeAbs + unallocatedIncome;
      final totalExpenses = totalAllExpensesAbs + unallocatedExpenses;

      emit(
        state.copyWith(
          status: Status.success,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          totalTransfers: totalTransfers,
          unallocatedIncome: unallocatedIncome,
          unallocatedExpenses: unallocatedExpenses,
          incomeTagSummaries: incomeTagSummaries,
          expenseTagSummaries: expenseTagSummaries,
          transferTagSummaries: transferTagSummaries,
          predictionByTagId: predictionByTagId,
          firstUnallocatedTurnover: firstUnallocatedTurnover,
          unallocatedCountInPeriod: unallocatedCountInPeriod,
          tagTurnoverCount: tagTurnoverCount,
        ),
      );
    } catch (e, s) {
      log.e('Failed to load period data', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load period data: $e',
        ),
      );
    }
  }

  Future<(int, Decimal)> _pending() async {
    final pendingTurnovers = await _tagTurnoverRepository.getUnmatched();
    final count = pendingTurnovers.length;
    final totalAmount = pendingTurnovers
        .map((tt) => tt.amountValue.abs())
        .fold(Decimal.zero, (sum, amount) => sum + amount);
    return (count, totalAmount);
  }

  Future<(List<TagSummary>, Decimal)> _loadTransfersSummary(
    Period period,
  ) async {
    // LOGIC per prds/20251214-transfers.md O4:
    // Only use 'from' side (TurnoverSign.expense) for calculations.
    // The 'from' side has negative amounts and represents the transfer out.
    // The 'to' side (TurnoverSign.income) is ignored to avoid double-counting.

    final expenseSummaries = await _tagTurnoverRepository
        .getTagSummariesForPeriod(
          period,
          TurnoverSign.expense,
          semantic: TagSemantic.transfer,
        );

    // Total transfer amount = sum of absolute values from 'from' side
    final totalTransferExpenses = expenseSummaries.fold<Decimal>(
      Decimal.zero,
      (sum, s) => sum + s.totalAmount.abs(),
    );

    // For display: only show expense summaries (the 'from' sides)
    final transferTagSummaries = expenseSummaries
        .map((s) => s.copyWith(totalAmount: s.totalAmount.abs()))
        .toList();

    // Total transfers = sum of 'from' side amounts
    final totalTransfers = totalTransferExpenses;

    return (transferTagSummaries, totalTransfers);
  }

  /// Calculates predictions for all tags based on historical data.
  ///
  /// Looks back [historicalPeriodCount] periods (default 3) and calculates
  /// the average spending per tag across those periods.
  Future<Map<TurnoverSign, Map<UuidValue, TagPrediction>>>
  _calculatePredictionByTagId(
    Period currentPeriod, {
    int historicalPeriodCount = 3,
  }) async {
    // Generate historical periods (e.g., last 3 months)
    final historicalPeriods = List.generate(
      historicalPeriodCount,
      (i) => currentPeriod.add(delta: -(i + 1)),
    );

    // Fetch summaries for all historical periods in parallel
    final summariesByPeriod = await Future.wait(
      historicalPeriods.map((period) async {
        final income = await _tagTurnoverRepository.getTagSummariesForPeriod(
          period,
          TurnoverSign.income,
          semantic: null,
        );
        final expense = await _tagTurnoverRepository.getTagSummariesForPeriod(
          period,
          TurnoverSign.expense,
          semantic: null,
        );
        return (income, expense);
      }),
    );

    // Aggregate amounts by tag across all periods
    final amountsBySign = <TurnoverSign, Map<UuidValue, List<Decimal>>>{};

    for (final (income, expense) in summariesByPeriod) {
      for (final it in income) {
        amountsBySign
            .putIfAbsent(TurnoverSign.income, () => {})
            .putIfAbsent(it.tagId, () => [])
            .add(it.totalAmount);
      }
      for (final it in expense) {
        amountsBySign
            .putIfAbsent(TurnoverSign.expense, () => {})
            .putIfAbsent(it.tagId, () => [])
            .add(it.totalAmount);
      }
    }

    // Calculate averages and create predictions
    final predictions = <TurnoverSign, Map<UuidValue, TagPrediction>>{};

    for (final sign in amountsBySign.keys) {
      final amountsByTag = amountsBySign[sign]!;
      for (final MapEntry(key: tagId, value: amounts) in amountsByTag.entries) {
        final periodsWithData = amounts.length;

        // Calculate average across periods where tag appears
        final total = amounts.fold<Decimal>(
          Decimal.zero,
          (sum, amount) => sum + amount,
        );
        final average = (total / Decimal.fromInt(periodsWithData)).toDecimal(
          scaleOnInfinitePrecision: 2,
        );

        predictions.putIfAbsent(sign, () => {})[tagId] = TagPrediction(
          averageFromHistory: average,
          periodsAnalyzed: periodsWithData,
        );
      }
    }

    return predictions;
  }

  /// Sets a specific period.
  Future<void> selectPeriod(Period period) async {
    emit(state.copyWith(period: period));
    await loadPeriodData(invalidateNonPeriodData: true);
  }
}

enum TurnoverType { expense, transfer, income }
