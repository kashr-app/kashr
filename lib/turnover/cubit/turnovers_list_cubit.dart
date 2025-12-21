import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

/// Cubit for managing paginated turnovers list with infinite scroll.
class TurnoversListCubit extends Cubit<TurnoversListState> {
  final TurnoverRepository turnoverRepository;
  final TagTurnoverRepository tagTurnoverRepository;
  final log = Logger();

  static const int pageSize = 10;

  TurnoversListCubit(this.turnoverRepository, this.tagTurnoverRepository)
    : super(const TurnoversListState.initial());

  /// Fetches the next page of turnovers.
  Future<void> fetchPage(int pageKey) async {
    try {
      final turnovers = await turnoverRepository.getTurnoversPaginated(
        limit: pageSize,
        offset: pageKey,
      );

      final isLastPage = turnovers.length < pageSize;
      final nextPageKey = isLastPage ? null : pageKey + turnovers.length;

      final turnoverIds = turnovers.map((it) => it.id);

      final tagTurnoversByTurnoverId = await tagTurnoverRepository
          .getByTurnoverIds(turnoverIds);

      final newItems = turnovers.map(
        (t) => TurnoverWithTagTurnovers(
          turnover: t,
          tagTurnovers: tagTurnoversByTurnoverId[t.id]?.values.toList() ?? [],
        ),
      );

      emit(
        TurnoversListState.loaded(
          items: [...state.items, ...newItems],
          nextPageKey: nextPageKey,
          error: null,
        ),
      );
    } catch (error, stackTrace) {
      log.e(
        'Error fetching turnovers page',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        TurnoversListState.loaded(
          items: state.items,
          nextPageKey: state.nextPageKey,
          error: error,
        ),
      );
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
  final List<TurnoverWithTagTurnovers> items;
  final int? nextPageKey;
  final Object? error;

  const TurnoversListState({required this.items, this.nextPageKey, this.error});

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
