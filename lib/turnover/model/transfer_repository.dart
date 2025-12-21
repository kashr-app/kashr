import 'dart:async';

import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/transfer.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/transfers_filter.dart';
import 'package:uuid/uuid.dart';

/// Type of transfer item for pagination.
enum TransferItemType { transfer, unlinkedTagTurnover }

/// Lightweight pointer to a transfer item for pagination.
///
/// Used to get ordered items without fetching full entities.
class TransferItemPointer {
  final UuidValue id;
  final TransferItemType type;
  final DateTime sortDate;

  const TransferItemPointer({
    required this.id,
    required this.type,
    required this.sortDate,
  });
}

/// Repository for managing Transfer entities.
///
/// Handles CRUD operations for transfers and their relationships to
/// TagTurnovers via the transfer_tag_turnover junction table.
class TransferRepository {
  final StreamController<TransferChange> _changeController =
      StreamController<TransferChange>.broadcast();

  /// Stream of transfer changes for reactive updates.
  Stream<TransferChange> watchChanges() => _changeController.stream;

  /// Disposes the repository and closes the change stream.
  void dispose() {
    _changeController.close();
  }

  /// Creates a new transfer linking two tag turnovers.
  ///
  /// Does only create the [Transfer] from [transferWithDetails] and does not check if the details match.
  ///
  /// Both tagTurnovers must already exist in the database.
  /// Enforces that each tagTurnover is used at most once (via UNIQUE constraint).
  Future<void> createTransfer(TransferWithDetails transferWithDetails) async {
    final db = await DatabaseHelper().database;

    // Use transaction to ensure atomicity
    await db.transaction((txn) async {
      // Convert to JSON for consistent serialization
      final json = transferWithDetails.transfer.toJson();

      // Insert transfer (omit from/to fields as they're in junction table)
      await txn.insert('transfer', {
        'id': json['id'],
        'created_at': json['created_at'],
        'confirmed_at': json['confirmed_at'],
      });

      // Insert from relationship if present
      if (transferWithDetails.transfer.fromTagTurnoverId != null) {
        await txn.insert('transfer_tag_turnover', {
          'transfer_id': json['id'],
          'tag_turnover_id':
              transferWithDetails.transfer.fromTagTurnoverId!.uuid,
          'role': 'from',
        });
      }

      // Insert to relationship if present
      if (transferWithDetails.transfer.toTagTurnoverId != null) {
        await txn.insert('transfer_tag_turnover', {
          'transfer_id': json['id'],
          'tag_turnover_id': transferWithDetails.transfer.toTagTurnoverId!.uuid,
          'role': 'to',
        });
      }
    });

    _changeController.add(TransferCreated(transferWithDetails));
  }

  /// Updates the from and/or to tag turnover IDs of a transfer.
  ///
  /// If [baseChanged] is true, the base fields of the entity are updated.
  /// Defaults to true.
  ///
  /// If [assocsChanged] is true, the associations (from/to) are updated.
  /// Defaults to true.
  Future<Transfer> updateTransfer(
    Transfer transfer, {
    baseChanged = true,
    assocsChanged = true,
  }) async {
    final db = await DatabaseHelper().database;

    await db.transaction((txn) async {
      final json = transfer.toJson();

      if (baseChanged) {
        await txn.update(
          'transfer',
          {
            'created_at': json['created_at'],
            'confirmed_at': json['confirmed_at'],
          },
          where: 'id = ?',
          whereArgs: [json['id']],
        );
      }

      if (assocsChanged) {
        // Delete existing relationships
        await txn.delete(
          'transfer_tag_turnover',
          where: 'transfer_id = ?',
          whereArgs: [json['id']],
        );

        // Re-insert from relationship if present
        if (transfer.fromTagTurnoverId != null) {
          await txn.insert('transfer_tag_turnover', {
            'transfer_id': json['id'],
            'tag_turnover_id': transfer.fromTagTurnoverId!.uuid,
            'role': 'from',
          });
        }

        // Re-insert to relationship if present
        if (transfer.toTagTurnoverId != null) {
          await txn.insert('transfer_tag_turnover', {
            'transfer_id': json['id'],
            'tag_turnover_id': transfer.toTagTurnoverId!.uuid,
            'role': 'to',
          });
        }
      }
    });

    _changeController.add(TransferUpdated(transfer));
    return transfer;
  }

  /// Deletes a transfer.
  ///
  /// The CASCADE constraint will automatically delete the junction table rows.
  Future<void> deleteTransfer(Transfer transfer) async {
    final db = await DatabaseHelper().database;
    final json = transfer.toJson();

    await db.delete('transfer', where: 'id = ?', whereArgs: [json['id']]);

    _changeController.add(TransferDeleted(transfer));
  }

  /// Gets the transfers by their IDs.
  Future<Map<UuidValue, Transfer>> getTransfersByIds(
    Iterable<UuidValue> transferIds,
  ) async {
    final db = await DatabaseHelper().database;

    final (placeholders, args) = db.inClause(
      transferIds,
      toArg: (it) => it.uuid,
    );

    final result = await db.rawQuery('''
      SELECT
        t.id,
        t.created_at,
        t.confirmed_at,
        from_tt.tag_turnover_id as from_tag_turnover_id,
        to_tt.tag_turnover_id as to_tag_turnover_id
      FROM transfer t
      LEFT JOIN transfer_tag_turnover from_tt
        ON t.id = from_tt.transfer_id AND from_tt.role = 'from'
      LEFT JOIN transfer_tag_turnover to_tt
        ON t.id = to_tt.transfer_id AND to_tt.role = 'to'
      WHERE t.id IN ($placeholders)
    ''', args.toList());

    final transferById = <UuidValue, Transfer>{};
    for (final map in result) {
      final t = Transfer.fromJson(map);
      transferById[t.id] = t;
    }
    return transferById;
  }

  /// Gets the transfer for a given tag turnover (if it exists).
  Future<Transfer?> getTransferForTagTurnover(UuidValue tagTurnoverId) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT
        t.id,
        t.created_at,
        t.confirmed_at,
        from_tt.tag_turnover_id as from_tag_turnover_id,
        to_tt.tag_turnover_id as to_tag_turnover_id
      FROM transfer t
      LEFT JOIN transfer_tag_turnover from_tt
        ON t.id = from_tt.transfer_id AND from_tt.role = 'from'
      LEFT JOIN transfer_tag_turnover to_tt
        ON t.id = to_tt.transfer_id AND to_tt.role = 'to'
      WHERE from_tt.tag_turnover_id = ? OR to_tt.tag_turnover_id = ?
    ''',
      [tagTurnoverId.uuid, tagTurnoverId.uuid],
    );

    if (result.isEmpty) return null;

    return Transfer.fromJson(result.first);
  }

  /// Checks which of the given tag turnover IDs are linked to transfers.
  ///
  /// Returns a map of tagTurnoverId to transferId for those that are linked.
  Future<Map<UuidValue, UuidValue>> getTransferIdsForTagTurnovers(
    List<UuidValue> tagTurnoverIds,
  ) async {
    if (tagTurnoverIds.isEmpty) return {};

    final db = await DatabaseHelper().database;
    final (placeholders, args) = db.inClause(
      tagTurnoverIds,
      toArg: (id) => id.uuid,
    );

    final result = await db.rawQuery(
      '''
      SELECT tag_turnover_id, transfer_id
      FROM transfer_tag_turnover
      WHERE tag_turnover_id IN ($placeholders)
    ''',
      [...args],
    );

    return Map.fromEntries(
      result.map(
        (row) => MapEntry(
          UuidValue.fromString(row['tag_turnover_id'] as String),
          UuidValue.fromString(row['transfer_id'] as String),
        ),
      ),
    );
  }

  final _needsReviewJoinWhere = '''
      LEFT JOIN transfer_tag_turnover from_tt
        ON t.id = from_tt.transfer_id AND from_tt.role = 'from'
      LEFT JOIN tag_turnover from_tt_data
        ON from_tt.tag_turnover_id = from_tt_data.id
      LEFT JOIN tag from_tag
        ON from_tt_data.tag_id = from_tag.id
      LEFT JOIN transfer_tag_turnover to_tt
        ON t.id = to_tt.transfer_id AND to_tt.role = 'to'
      LEFT JOIN tag_turnover to_tt_data
        ON to_tt.tag_turnover_id = to_tt_data.id
      LEFT JOIN tag to_tag
        ON to_tt_data.tag_id = to_tag.id
      WHERE
        -- Missing from or to side
        from_tt.tag_turnover_id IS NULL
        OR to_tt.tag_turnover_id IS NULL
        OR
        -- From tag not transfer
        (from_tag.id IS NULL OR from_tag.semantic != 'transfer')
        OR
        -- To tag not transfer
        (to_tag.id IS NULL OR to_tag.semantic != 'transfer')
        OR
        -- Tag mismatch
        from_tag.id != to_tag.id
        OR
        -- same account
        from_tt_data.account_id == to_tt_data.account_id
        OR
        -- from amount must be negative
        from_tt_data.amount_value >= 0
        OR
        -- to amount must be positive
        to_tt_data.amount_value < 0
        OR
        -- not confirmed but (amounts do not cancel out OR currency does not match)
        (
          t.confirmed_at IS NULL
          AND
          (
            (from_tt_data.amount_value + to_tt_data.amount_value) != 0
            OR
            from_tt_data.amount_unit != to_tt_data.amount_unit
          )
        )
  ''';

  /// Counts transfer items that need user review.
  Future<int> countTransferIds({
    TransfersFilter filter = TransfersFilter.empty,
  }) async {
    final db = await DatabaseHelper().database;
    var sql = '''
      SELECT COUNT(t.id) as count
      FROM transfer t
      ''';
    if (filter.needsReviewOnly) {
      sql += _needsReviewJoinWhere;
    }

    final result = await db.rawQuery(sql);
    return result.first['count'] as int;
  }

  /// Gets [TagTurnover] IDs with transfer semantic that are NOT linked to any [Transfer].
  ///
  /// These represent one side of a transfer that hasn't been paired with its
  /// counterpart yet.
  Future<int> countUnlinkedTransferTagTurnoverIds() async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery('''
      SELECT COUNT(tt.id) as count
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tag_id = t.id
      WHERE t.semantic = 'transfer'
        AND NOT EXISTS (
          SELECT 1 FROM transfer_tag_turnover ttt
          WHERE ttt.tag_turnover_id = tt.id
        )
      ORDER BY tt.booking_date DESC
    ''');

    return result.first['count'] as int;
  }

  /// Gets lightweight pointers to transfer items for pagination.
  ///
  /// This method performs a single query that combines both transfers and
  /// unlinked tag turnovers, sorted by date. Only fetches minimal data
  /// (id, type, sort date) to enable efficient pagination without loading
  /// full entities.
  ///
  /// The returned pointers can then be used to fetch full entities in batches.
  Future<List<TransferItemPointer>> getTransferItemPointers({
    required TransfersFilter filter,
    required int limit,
    required int offset,
    required bool includeUnlinkedTagTurnovers,
  }) async {
    final db = await DatabaseHelper().database;

    final queries = <String>[];
    final params = <Object>[];

    // Transfer query - get the most recent booking_date from either side
    var transferQuery = '''
      SELECT
        t.id,
        'transfer' as type,
        COALESCE(
          MAX(from_tt_data.booking_date, to_tt_data.booking_date),
          from_tt_data.booking_date,
          to_tt_data.booking_date
        ) as sort_date
      FROM transfer t
    ''';

    if (filter.needsReviewOnly) {
      transferQuery += _needsReviewJoinWhere;
    } else {
      // Still need to join to get booking dates for sorting
      transferQuery += '''
        LEFT JOIN transfer_tag_turnover from_tt
          ON t.id = from_tt.transfer_id AND from_tt.role = 'from'
        LEFT JOIN tag_turnover from_tt_data
          ON from_tt.tag_turnover_id = from_tt_data.id
        LEFT JOIN transfer_tag_turnover to_tt
          ON t.id = to_tt.transfer_id AND to_tt.role = 'to'
        LEFT JOIN tag_turnover to_tt_data
          ON to_tt.tag_turnover_id = to_tt_data.id
      ''';
    }

    // Group by transfer id since we might have multiple rows from joins
    transferQuery += '''
      GROUP BY t.id
    ''';

    queries.add(transferQuery);

    // Unlinked tag turnover query
    if (includeUnlinkedTagTurnovers) {
      queries.add('''
        SELECT
          tt.id,
          'unlinked_tag_turnover' as type,
          tt.booking_date as sort_date
        FROM tag_turnover tt
        INNER JOIN tag t ON tt.tag_id = t.id
        WHERE t.semantic = 'transfer'
          AND NOT EXISTS (
            SELECT 1 FROM transfer_tag_turnover ttt
            WHERE ttt.tag_turnover_id = tt.id
          )
      ''');
    }

    // Combine queries with UNION ALL
    final sql =
        '''
      ${queries.join('\nUNION ALL\n')}
      ORDER BY sort_date DESC NULLS FIRST
      LIMIT ? OFFSET ?
    ''';

    params.addAll([limit, offset]);

    final results = await db.rawQuery(sql, params);

    return results.map((row) {
      final typeStr = row['type'] as String;
      final type = typeStr == 'transfer'
          ? TransferItemType.transfer
          : TransferItemType.unlinkedTagTurnover;

      return TransferItemPointer(
        id: UuidValue.fromString(row['id'] as String),
        type: type,
        sortDate: DateTime.parse(row['sort_date'] as String),
      );
    }).toList();
  }

  /// Counts items that need user review.
  ///
  /// Includes both:
  /// - Invalid Transfer entities (from [countTransferIds])
  /// - Unlinked tagTurnovers with transfer semantic (from [countUnlinkedTransferTagTurnoverIds])
  Future<int> countTransfersNeedingReview({
    TransfersFilter filter = TransfersFilter.empty,
  }) async {
    final needReviewCount = await countTransferIds(filter: filter);
    final unlinkedTTCount = await countUnlinkedTransferTagTurnoverIds();
    return needReviewCount + unlinkedTTCount;
  }
}

/// Base class for transfer change events.
sealed class TransferChange {}

/// Emitted when a transfer is created.
class TransferCreated extends TransferChange {
  final TransferWithDetails transfer;
  TransferCreated(this.transfer);
}

/// Emitted when a transfer is updated.
class TransferUpdated extends TransferChange {
  final Transfer transfer;
  TransferUpdated(this.transfer);
}

/// Emitted when a transfer is deleted.
class TransferDeleted extends TransferChange {
  final Transfer transfer;
  TransferDeleted(this.transfer);
}
