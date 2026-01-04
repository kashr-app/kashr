import 'dart:developer' as developer;

import 'package:kashr/analytics/cubit/analytics_state.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class AnalyticsCubit extends Cubit<AnalyticsState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TagRepository _tagRepository;

  AnalyticsCubit(this._tagTurnoverRepository, this._tagRepository)
    : super(
        AnalyticsState(
          startDate: DateTime(DateTime.now().year, DateTime.now().month - 5, 1),
          endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 1),
        ),
      );

  Future<void> loadData() async {
    try {
      final isInitialLoad = state.status.isInitial;
      emit(state.copyWith(status: Status.loading));

      // Load all tags
      final allTags = await _tagRepository.getAllTagsCached();

      // If no tags are selected yet, select all tags
      final selectedTagIds = isInitialLoad && state.selectedTagIds.isEmpty
          ? allTags.map((t) => t.id).toList()
          : state.selectedTagIds;

      // Load data summaries for the selected date range
      final dataSummaries = await _tagTurnoverRepository
          .getTagSummariesForPeriodByMonth(
            period: Period(
              // TODO PeriodType.year is not really true because we show some months only, but good enough for now
              PeriodType.year,
              startInclusive: state.startDate,
              endExclusive: state.endDate,
            ),
            tagIds: selectedTagIds.isEmpty ? null : selectedTagIds,
          );

      emit(
        state.copyWith(
          status: Status.success,
          allTags: allTags,
          selectedTagIds: selectedTagIds,
          dataSummaries: dataSummaries,
        ),
      );
    } catch (e, s) {
      developer.log(
        'Failed to load analytics data',
        name: 'analytics',
        level: 1000,
        error: e,
        stackTrace: s,
      );
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load analytics data: $e',
        ),
      );
    }
  }

  void toggleTag(UuidValue tagId) {
    final selectedTagIds = List<UuidValue>.from(state.selectedTagIds);

    if (selectedTagIds.contains(tagId)) {
      selectedTagIds.remove(tagId);
    } else {
      selectedTagIds.add(tagId);
    }

    emit(state.copyWith(selectedTagIds: selectedTagIds));
    loadData();
  }

  void selectAllTags() {
    final allTagIds = state.allTags.map((t) => t.id).toList();
    emit(state.copyWith(selectedTagIds: allTagIds));
    loadData();
  }

  void deselectAllTags() {
    emit(state.copyWith(selectedTagIds: []));
    loadData();
  }
}
