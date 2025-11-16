import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

/// Cubit for managing paginated turnovers list with infinite scroll.
class TurnoversListCubit extends Cubit<TurnoversListState> {
  final TurnoverRepository turnoverRepository;
  final log = Logger();

  static const int pageSize = 10;

  TurnoversListCubit(this.turnoverRepository)
      : super(const TurnoversListState.initial());

  /// Fetches the next page of turnovers.
  Future<void> fetchPage(int pageKey) async {
    try {
      final newItems = await turnoverRepository.getTurnoversWithTagsPaginated(
        limit: pageSize,
        offset: pageKey,
      );

      final isLastPage = newItems.length < pageSize;
      final nextPageKey = isLastPage ? null : pageKey + newItems.length;

      emit(TurnoversListState.loaded(
        items: [...state.items, ...newItems],
        nextPageKey: nextPageKey,
        error: null,
      ));
    } catch (error, stackTrace) {
      log.e('Error fetching turnovers page', error: error, stackTrace: stackTrace);
      emit(TurnoversListState.loaded(
        items: state.items,
        nextPageKey: state.nextPageKey,
        error: error,
      ));
    }
  }

  /// Refreshes the list from the beginning.
  Future<void> refresh() async {
    emit(const TurnoversListState.initial());
    await fetchPage(0);
  }
}

/// State for the turnovers list.
class TurnoversListState {
  final List<TurnoverWithTags> items;
  final int? nextPageKey;
  final Object? error;

  const TurnoversListState({
    required this.items,
    this.nextPageKey,
    this.error,
  });

  const TurnoversListState.initial()
      : items = const [],
        nextPageKey = 0,
        error = null;

  const TurnoversListState.loaded({
    required this.items,
    required this.nextPageKey,
    required this.error,
  });
}
