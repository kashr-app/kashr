import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TurnoverService {
  final TurnoverRepository turnoverRepository;
  final TagTurnoverRepository tagTurnoverRepository;

  final Logger log;

  TurnoverService(
    this.turnoverRepository,
    this.tagTurnoverRepository,
    this.log,
  );

  Future<List<TurnoverWithTagTurnovers>> getTurnoversWithTags(
    Iterable<Turnover> turnovers,
  ) async {
    final turnoverIds = turnovers.map((it) => it.id);

    final tagTurnoversByTurnoverId = await tagTurnoverRepository
        .getByTurnoverIds(turnoverIds);

    final turnoversWithTT = <TurnoverWithTagTurnovers>[];
    for (final turnover in turnovers) {
      final tagTurnovers =
          tagTurnoversByTurnoverId[turnover.id]?.values.toList() ?? [];
      turnoversWithTT.add(
        TurnoverWithTagTurnovers(
          turnover: turnover,
          tagTurnovers: tagTurnovers,
        ),
      );
    }

    return turnoversWithTT;
  }

  /// Upserts turnovers by inserting new ones and updating existing ones.
  /// Uses apiId to determine if a turnover already exists for the account.
  ///
  /// Returns the ids of (new, updated) turnovers.
  Future<(Iterable<UuidValue> newIds, Iterable<UuidValue> existingIds)>
  upsertTurnovers(Iterable<Turnover> turnovers) async {
    // Group turnovers by accountId for efficient querying
    final turnoversByAccount = <UuidValue, List<Turnover>>{};
    for (final turnover in turnovers) {
      turnoversByAccount
          .putIfAbsent(turnover.accountId, () => [])
          .add(turnover);
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
      // We query per account because an apiId is not guaranteed to be unique across accounts
      final existingTurnovers = await turnoverRepository
          .getTurnoversByApiIdsForAccount(accountId: accountId, apiIds: apiIds);

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
              allToUpdate.add(
                turnover.copyWith(
                  id: existing.id,
                  createdAt: existing.createdAt,
                ),
              );
            }
          }
        }
      }
    }

    if (allToInsert.isEmpty && allToUpdate.isEmpty) {
      log.i('No turnovers to insert or update');
      return (<UuidValue>[], <UuidValue>[]);
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

    return (allToInsert.map((it) => it.id), allToUpdate.map((it) => it.id));
  }

  Future<Iterable<UuidValue>> filterUnmatched({
    required Iterable<UuidValue> turnoverIds,
  }) async {
    return await turnoverRepository.filterUnmatched(turnoverIds: turnoverIds);
  }
}
