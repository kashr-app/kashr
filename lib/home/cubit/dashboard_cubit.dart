import 'dart:async';

import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/core/extensions/decimal_extensions.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/ingest/ingest.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_change.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_change.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/services/turnover_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiffy/jiffy.dart';
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
          selectedPeriod: YearMonth.now(),
          totalIncome: Decimal.zero,
          totalExpenses: Decimal.zero,
          totalTransfers: Decimal.zero,
          unallocatedIncome: Decimal.zero,
          unallocatedExpenses: Decimal.zero,
          firstUnallocatedTurnover: null,
          unallocatedCount: 0,
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
        _affectsSelectedMonth,
      ),
      TurnoversUpdated(:final turnovers) => turnovers.any(
        _affectsSelectedMonth,
      ),
      TurnoversDeleted() => true, // Conservative: always refresh on deletes
    };

    if (shouldRefresh) {
      loadMonthData();
    }
  }

  void _onTagTurnoverChanged(TagTurnoverChange change) {
    final shouldRefresh = switch (change) {
      TagTurnoversInserted(:final tagTurnovers) => tagTurnovers.any(
        (tt) => _bookingDateInMonth(tt.bookingDate),
      ),
      TagTurnoversUpdated(:final tagTurnovers) => tagTurnovers.any(
        (tt) => _bookingDateInMonth(tt.bookingDate),
      ),
      TagTurnoversDeleted() => true, // Conservative: always refresh on deletes
    };

    if (shouldRefresh) {
      loadMonthData();
    }
  }

  void _onTagsChanged(List<Tag>? tags) {
    final shouldRefresh = true;
    if (shouldRefresh) {
      loadMonthData();
    }
  }

  void _onTransferChanged(TransferChange change) {
    loadMonthData();
  }

  /// Checks if a turnover affects the currently selected month.
  bool _affectsSelectedMonth(Turnover turnover) {
    final bookingDate = turnover.bookingDate;
    return bookingDate != null && _bookingDateInMonth(bookingDate);
  }

  /// Checks if a booking date falls within the selected month.
  bool _bookingDateInMonth(DateTime date) {
    final ym = YearMonth(year: date.year, month: date.month);
    return ym == state.selectedPeriod;
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

    final start = state.selectedPeriod.toDateTime();
    final end = Jiffy.parseFromDateTime(start).endOf(Unit.month).dateTime;

    final result = await ingestor.ingest(
      minBookingDate: start,
      maxBookingDate: end,
    );

    switch (result.status) {
      case ResultStatus.success:
        setBankDownloadStatus(Status.success);
        loadMonthData();
      case ResultStatus.unauthed:
        setBankDownloadStatus(Status.initial);
      case ResultStatus.otherError:
        setBankDownloadStatus(Status.error);
    }
    return result;
  }

  /// Loads cashflow data for the currently selected month.
  Future<void> loadMonthData() async {
    emit(state.copyWith(status: Status.loading));

    // Get current tags from repository
    final tags = await _tagRepository.getAllTagsCached();
    final tagById = tags.associateBy((it) => it.id);

    try {
      final turnovers = await _turnoverRepository.getTurnoversForMonth(
        state.selectedPeriod,
      );

      final tagTurnoverCount = await _tagTurnoverRepository.count(
        state.selectedPeriod,
      );

      final incomeTagSummaries = await _tagTurnoverRepository
          .getTagSummariesForMonth(
            state.selectedPeriod,
            TurnoverSign.income,
            semantic: null, // excludes transfers
          );

      final expenseTagSummaries = await _tagTurnoverRepository
          .getTagSummariesForMonth(
            state.selectedPeriod,
            TurnoverSign.expense,
            semantic: null, // excludes transfers
          );

      final (transferTagSummaries, totalTransfers) =
          await _loadTransfersSummary();

      final firstUnallocatedTurnovers = (await _turnoverRepository
          .getUnallocatedTurnoversForMonth(state.selectedPeriod, limit: 1));
      final firstUnallocatedTurnover =
          (await _turnoverService.getTurnoversWithTags(
            firstUnallocatedTurnovers,
          )).firstOrNull;

      final unallocatedCount = await _turnoverRepository
          .countUnallocatedTurnoversForMonth(state.selectedPeriod);

      // Fetch tag turnovers for correct total calculation
      final startDate = state.selectedPeriod.toDateTime();
      final endDate = Jiffy.parseFromDateTime(
        startDate,
      ).add(months: 1).dateTime;

      final ttData = await _tagTurnoverRepository
          .getTagTurnoversForMonthlyDashboard(
            startDate: startDate,
            endDate: endDate,
          );

      // Calculate total income/expense using tag booking dates + untagged portions

      // 1. Sum from tag turnovers allocated in this month (by tt.booking_date)
      final totalAbsTTByType = ttData.allocatedInMonth
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

      // 2. Calculate untagged portions of turnovers in this month
      // Build map of tagged amounts per turnover
      final ttByTurnoverId = [
        ...ttData.allocatedInMonth,
        ...ttData.allocatedOutsideMonthButTurnoverInMonth,
      ].groupListsBy((it) => it.turnoverId);

      final taggedAmountByTurnover = <UuidValue, Decimal>{};
      final totalAbsUntaggedBySign = <TurnoverSign, Decimal>{};
      for (final turnover in turnovers) {
        final turnoverId = turnover.id;
        final taggedAmount =
            ttByTurnoverId[turnoverId]?.sum((it) => it.amountValue) ??
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

      final (pendingCount, pendingTotalAmount) = await _pending();
      final transfersNeedingReviewCount = await _transferRepository
          .countTransfersNeedingReview();

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
          firstUnallocatedTurnover: firstUnallocatedTurnover,
          unallocatedCount: unallocatedCount,
          pendingCount: pendingCount,
          pendingTotalAmount: pendingTotalAmount,
          transfersNeedingReviewCount: transfersNeedingReviewCount,
          tagTurnoverCount: tagTurnoverCount,
        ),
      );
    } catch (e, s) {
      log.e('Failed to load month data', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load spending data: $e',
        ),
      );
    }
  }

  Future<(int, Decimal)> _pending() async {
    final pendingTurnovers = await _tagTurnoverRepository.getUnmatched();
    final count = pendingTurnovers.length;
    final totalAmount = pendingTurnovers
        .map((tt) => tt.amountValue)
        .fold(Decimal.zero, (sum, amount) => sum + amount);
    return (count, totalAmount);
  }

  Future<(List<TagSummary>, Decimal)> _loadTransfersSummary() async {
    // LOGIC per prds/20251214-transfers.md O4:
    // Only use 'from' side (TurnoverSign.expense) for calculations.
    // The 'from' side has negative amounts and represents the transfer out.
    // The 'to' side (TurnoverSign.income) is ignored to avoid double-counting.

    final expenseSummaries = await _tagTurnoverRepository
        .getTagSummariesForMonth(
          state.selectedPeriod,
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

  /// Navigates to the previous month.
  Future<void> previousMonth() async {
    final currentDate = state.selectedPeriod.toDateTime();
    final previousDate = DateTime(currentDate.year, currentDate.month - 1);
    emit(
      state.copyWith(
        selectedPeriod: YearMonth(
          year: previousDate.year,
          month: previousDate.month,
        ),
      ),
    );
    await loadMonthData();
  }

  /// Navigates to the next month.
  Future<void> nextMonth() async {
    final currentDate = state.selectedPeriod.toDateTime();
    final nextDate = DateTime(currentDate.year, currentDate.month + 1);
    emit(
      state.copyWith(
        selectedPeriod: YearMonth(year: nextDate.year, month: nextDate.month),
      ),
    );
    await loadMonthData();
  }

  /// Sets a specific month and year.
  Future<void> selectMonth(YearMonth yearMonth) async {
    emit(state.copyWith(selectedPeriod: yearMonth));
    await loadMonthData();
  }
}

enum TurnoverType { expense, transfer, income }
