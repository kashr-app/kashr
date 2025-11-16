import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/cubit/turnover_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TurnoverCubit extends Cubit<TurnoverState> {
  final TurnoverRepository turnoverRepository;

  final log = Logger();

  TurnoverCubit(this.turnoverRepository)
      : super(const TurnoverState(
          status: Status.initial,
          turnovers: [],
        ));

  Future<void> loadTurnoversByApiIds(List<UuidValue> apiIds) async {
    final turnovers = await turnoverRepository.getTurnoversByApiIds(apiIds);
    emit(state.copyWith(
      status: Status.success,
      turnovers: turnovers,
    ));
  }

  Future<void> addTurnover(Turnover turnover) async {
    await turnoverRepository.createTurnover(turnover);
    emit(state.copyWith(
      status: Status.success,
      turnovers: [turnover, ...state.turnovers],
    ));
  }

  Future<void> loadAllTurnovers() async {
    final all = await turnoverRepository.getTurnovers();
    emit(state.copyWith(
      status: Status.success,
      turnovers: all,
    ));
  }

  /// Stores turnovers that haven't been persisted before, filtering based on the (accountId, apiId) combination.
  Future<List<Turnover>> storeNonExisting(List<Turnover> turnovers) async {
    // Extract the non-null apiIds
    final turnoverApiIdsToCheck = turnovers
        .where((turnover) => turnover.apiId != null)
        .map((turnover) => turnover.apiId!)
        .toList();

    // Fetch existing pairs of (accountId, apiId) from the database
    final existingAccountApiIdPairs =
        await turnoverRepository.findAccountIdAndApiIdIn(turnoverApiIdsToCheck);

    // Filter out turnovers whose (accountId, apiId) combination already exists in the database
    final newTurnovers = turnovers.where((turnover) {
      if (turnover.apiId != null) {
        return !existingAccountApiIdPairs.contains(
          TurnoverAccountIdAndApiId(
            accountId: turnover.accountId,
            apiId: turnover.apiId!,
          ),
        );
      }
      return true; // Allow turnovers with null apiId
    }).toList();

    if (existingAccountApiIdPairs.isNotEmpty) {
      log.w(
        'Will not store ${existingAccountApiIdPairs.length} turnovers out of ${turnovers.length} total, '
        'because their apiId was already used in the same account.',
      );
    }

    // Store the new turnovers in the database
    final storedTurnovers = await turnoverRepository.saveAll(newTurnovers);
    log.i('Stored ${newTurnovers.length} turnovers');

    return storedTurnovers;
  }
}
