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

  /// Upserts turnovers by inserting new ones and updating existing ones.
  /// Uses apiId to determine if a turnover already exists for the account.
  /// Performs batch operations to avoid N+1 queries.
  Future<void> upsertTurnovers(List<Turnover> turnovers) async {
    // Group turnovers by accountId for efficient querying
    final turnoversByAccount = <UuidValue, List<Turnover>>{};
    for (final turnover in turnovers) {
      turnoversByAccount.putIfAbsent(turnover.accountId, () => []).add(turnover);
    }

    final allToInsert = <Turnover>[];
    final allToUpdate = <Turnover>[];

    for (final entry in turnoversByAccount.entries) {
      final accountId = entry.key;
      final accountTurnovers = entry.value;

      final apiIds = accountTurnovers
          .where((t) => t.apiId != null)
          .map((t) => t.apiId!)
          .toList();

      // Fetch existing turnovers for this account in one query
      final existingTurnovers =
          await turnoverRepository.getTurnoversByApiIdsForAccount(
        accountId: accountId,
        apiIds: apiIds,
      );

      // Create lookup map: apiId -> existing Turnover
      final existingByApiId = <String, Turnover>{
        for (final existing in existingTurnovers)
          if (existing.apiId != null) existing.apiId!: existing,
      };

      // Classify each turnover as insert or update
      for (final turnover in accountTurnovers) {
        if (turnover.apiId == null) {
          // No apiId means it's not originating from an api (unsynced account
          // and we hence always treat it as a new turnover
          allToInsert.add(turnover);
        } else {
          final existing = existingByApiId[turnover.apiId];
          if (existing == null) {
            // New turnover
            allToInsert.add(turnover);
          } else {
            // Existing turnover - check if it needs updating by normalizing
            // metadata fields and using freezed's generated equality
            final normalizedExisting = existing.copyWith(
              createdAt: DateTime(2000),
              accountId: turnover.accountId,
              apiId: turnover.apiId,
            );
            final normalizedTurnover = turnover.copyWith(
              id: existing.id,
              createdAt: DateTime(2000),
            );

            if (normalizedExisting != normalizedTurnover) {
              // Update with existing ID to preserve database identity
              allToUpdate.add(turnover.copyWith(
                id: existing.id,
                createdAt: existing.createdAt,
              ));
            }
          }
        }
      }
    }

    // Perform batch operations
    if (allToInsert.isNotEmpty) {
      await turnoverRepository.saveAll(allToInsert);
      log.i('Inserted ${allToInsert.length} new turnovers');
    }

    if (allToUpdate.isNotEmpty) {
      await turnoverRepository.batchUpdate(allToUpdate);
      log.i('Updated ${allToUpdate.length} existing turnovers');
    }

    if (allToInsert.isEmpty && allToUpdate.isEmpty) {
      log.i('No turnovers to insert or update');
    }
  }
}
