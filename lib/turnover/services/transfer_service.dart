import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/map_values.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/transfer.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_item.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/transfers_filter.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TransferService {
  final TransferRepository transferRepository;
  final TagTurnoverRepository tagTurnoverRepository;
  final TagRepository tagRepository;
  final _log = Logger();

  TransferService({
    required this.transferRepository,
    required this.tagTurnoverRepository,
    required this.tagRepository,
  });

  Future<TransferWithDetails?> getTransferWithDetails(
    UuidValue transferId,
  ) async {
    final byId = await getTransfersWithDetails([transferId]);
    return byId[transferId];
  }

  Future<Map<UuidValue, TransferWithDetails>> getTransfersWithDetails(
    Iterable<UuidValue> transferIds,
  ) async {
    if (transferIds.isEmpty) return {};

    final transfers = await transferRepository.getTransfersByIds(transferIds);

    final ttIds = transfers.values
        .expand((it) => [it.fromTagTurnoverId, it.toTagTurnoverId])
        .nonNulls;

    final ttById = await tagTurnoverRepository.getByIds(ttIds);

    final tagById = await tagRepository.getByIdsCached();

    final transfersById = transfers.mapValues((id, t) {
      final fromTT = ttById[t.fromTagTurnoverId];
      final toTT = ttById[t.toTagTurnoverId];
      return TransferWithDetails(
        transfer: t,
        fromTagTurnover: fromTT,
        toTagTurnover: toTT,
        fromTag: tagById[fromTT?.tagId],
        toTag: tagById[toTT?.tagId],
      );
    });

    return transfersById;
  }

  /// Fetches all items needing review.
  ///
  /// Returns a map indexed by ID containing both:
  /// - Invalid Transfer entities
  /// - Unlinked tagTurnovers with transfer semantic
  ///
  /// Uses proper pagination that combines both types of items in a single
  /// sorted result set.
  Future<Map<UuidValue, TransferItem>> getTransferReviewItems({
    required TransfersFilter filter,
    required int limit,
    required int offset,
    bool includeUnlinked = true,
  }) async {
    // 1. Get sorted pointers (lightweight)
    final pointers = await transferRepository.getTransferItemPointers(
      filter: filter,
      limit: limit,
      offset: offset,
      includeUnlinkedTagTurnovers: includeUnlinked,
    );

    // 2. Group IDs by type
    final idsByType = pointers
        .groupListsBy((p) => p.type)
        .mapValues((t, it) => it.map((i) => i.id));
    final transferIds = idsByType[TransferItemType.transfer] ?? [];
    final ttIds = idsByType[TransferItemType.unlinkedTagTurnover] ?? [];

    // 3. Fetch full entities in parallel using existing methods
    final transfersFuture = getTransfersWithDetails(transferIds);
    final ttFuture = tagTurnoverRepository.getByIds(ttIds);
    final fetchResults = await Future.wait([transfersFuture, ttFuture]);
    final transfersMap = fetchResults[0] as Map<UuidValue, TransferWithDetails>;
    final tagTurnoversMap = fetchResults[1] as Map<UuidValue, TagTurnover>;

    // Get tags for unlinked tag turnovers
    Map<UuidValue, dynamic> tagById = {};
    if (ttIds.isNotEmpty) {
      tagById = await tagRepository.getByIdsCached();
    }

    // 4. Build results in the correct order from pointers
    final results = <UuidValue, TransferItem>{};

    for (final pointer in pointers) {
      if (pointer.type == TransferItemType.transfer) {
        final details = transfersMap[pointer.id];
        if (details != null) {
          results[pointer.id] = TransferItem.withTransfer(
            transferWithDetails: details,
          );
        }
      } else {
        final tt = tagTurnoversMap[pointer.id];
        if (tt != null) {
          final tag = tagById[tt.tagId];
          if (tag != null) {
            results[pointer.id] = TransferItem.unlinkedFromTransfer(
              tagTurnover: tt,
              tag: tag,
            );
          }
        }
      }
    }

    return results;
  }

  /// Links [selectedTagTurnover] to [sourceTagTurnover].
  ///
  /// Optionally, provide [transfer] if [selectedTagTurnover] is already
  /// connected to a transfer and it is at hand. Otherwise the method will
  /// check the DB for such an existing transfer. If it is present this
  /// transfer will be prefered over a potentially existing one that the
  /// [selectedTagTurnover] might be associated with.
  ///
  /// Returns a record with:
  /// - transferId: The updated or created transfer ID (null if conflict)
  /// - conflict: The conflict type (null if success)
  ///
  /// Checks if [selectedTagTurnover] is already in another transfer and resolves
  /// conflicts if possible. Conflict resolution behavior:
  /// - If selected TT is in a complete transfer: conflict = completedTransfer
  /// - If selected TT has same sign as source: conflict = sameSigns
  /// - If selected TT is in an incomplete transfer with opposite sign: no conflict, deletes
  ///   the incomplete transfer in case [transfer] is not null or uses it for the linking.
  Future<(UuidValue? transferId, TransferLinkConflict? conflict)>
  linkTransferTagTurnovers({
    required TagTurnover? sourceTagTurnover,
    required TagTurnover selectedTagTurnover,
    Transfer? transfer,
  }) async {
    if (transfer == null && sourceTagTurnover != null) {
      transfer = await transferRepository.getTransferForTagTurnover(
        sourceTagTurnover.id,
      );
    }
    final bothSidesSet =
        (transfer?.fromTagTurnoverId != null &&
        transfer?.toTagTurnoverId != null);
    if (bothSidesSet) {
      throw Exception(
        'Source transfer has both sides set.'
        ' This method should never be called and is likely a UI flow bug.',
      );
    }

    // Check for conflicts on selected TT
    final (conflict, existingDetails) = await _checkConflictForLinking(
      selectedTagTurnover: selectedTagTurnover,
      sourceTagTurnover: sourceTagTurnover,
      deleteExistingTransferIfPossible: transfer != null,
    );

    if (conflict != null) {
      _log.d('Conflict creating transfer: ${conflict.message()}');
      return (null, conflict);
    }

    // the existing transfer we will update. If null, a new one will be created
    transfer = transfer ?? existingDetails?.transfer;

    // Determine which is FROM (negative) and which is TO (positive)
    final fromTT = selectedTagTurnover.amountValue < Decimal.zero
        ? selectedTagTurnover
        : sourceTagTurnover;
    final toTT = selectedTagTurnover.amountValue < Decimal.zero
        ? sourceTagTurnover
        : selectedTagTurnover;

    // Update or create new Transfer
    final toPersist =
        transfer?.copyWith(
          fromTagTurnoverId: fromTT?.id,
          toTagTurnoverId: toTT?.id,
        ) ??
        Transfer(
          id: UuidValue.fromString(const Uuid().v4()),
          fromTagTurnoverId: fromTT?.id,
          toTagTurnoverId: toTT?.id,
          createdAt: DateTime.now(),
          confirmedAt: null,
        );

    final tagById = await tagRepository.getByIdsCached();

    if (transfer != null) {
      await transferRepository.updateTransfer(toPersist, assocsChanged: true);
    } else {
      final transferWithDetails = TransferWithDetails(
        transfer: toPersist,
        fromTagTurnover: fromTT,
        toTagTurnover: toTT,
        fromTag: fromTT == null ? null : tagById[fromTT.tagId],
        toTag: toTT == null ? null : tagById[toTT.tagId],
      );
      await transferRepository.createTransfer(transferWithDetails);
    }
    return (toPersist.id, null);
  }

  /// Checks if linking [selectedTagTurnover] creates a conflict.
  ///
  /// Returns null if no conflict, otherwise returns the conflict type.
  /// If the conflict can be resolved (e.g., deleting an incomplete transfer),
  /// this method resolves it automatically.
  ///
  /// Parameters:
  /// - [sourceTagTurnover]: Tag turnover to which selected should be linked
  /// - [selectedTagTurnover]: Tag turnover being linked
  Future<
    (TransferLinkConflict? conflict, TransferWithDetails? existingTransfer)
  >
  _checkConflictForLinking({
    // source can be null in case an empty source transfer exists
    // (having no side set)
    required TagTurnover? sourceTagTurnover,
    required TagTurnover selectedTagTurnover,
    required bool deleteExistingTransferIfPossible,
  }) async {
    if (sourceTagTurnover?.id == selectedTagTurnover.id) {
      // should never happen because the app should exclude providing this option automatically.
      throw Exception('Cannot link a tag turnover with itself');
    }
    final existingTransfer = await transferRepository.getTransferForTagTurnover(
      selectedTagTurnover.id,
    );
    if (existingTransfer == null) {
      return (null, null); // No conflict
    }

    var existingDetails = await getTransferWithDetails(existingTransfer.id);
    if (existingDetails == null) {
      // should never happenbecause the transfer exists.
      throw Exception('Could not load existing transfer details');
    }
    // Selected TT is already in a transfer - check if we can resolve

    final hasBothSides =
        existingDetails.fromTagTurnover != null &&
        existingDetails.toTagTurnover != null;

    if (hasBothSides) {
      // Cannot use - already in complete transfer
      return (TransferLinkConflict.completedTransfer, existingDetails);
    }

    final existingSide =
        existingDetails.fromTagTurnover ?? existingDetails.toTagTurnover;

    if (existingSide == null) {
      // Transfer has no sides - delete it or use it and proceed
      if (deleteExistingTransferIfPossible) {
        await transferRepository.deleteTransfer(existingDetails.transfer);
        existingDetails = null;
      }
      return (null, existingDetails);
    }

    // Check sign compatibility if we have a source
    if (sourceTagTurnover != null &&
        sourceTagTurnover.sign == existingSide.sign) {
      return (TransferLinkConflict.sameSigns, existingDetails);
    }

    // Has opposite sign delete or reuse the incomplete transfer and proceed
    if (deleteExistingTransferIfPossible) {
      await transferRepository.deleteTransfer(existingDetails.transfer);
      existingDetails = null;
    }
    return (null, existingDetails);
  }
}

/// Conflict types when linking tag turnovers to transfers.
///
/// This enum replaces ConflictResolution from TransferEditorCubit and is used
/// across the codebase for consistent conflict handling.
enum TransferLinkConflict {
  /// The selected tag turnover has the same sign as the existing side.
  sameSigns,

  /// The selected tag turnover is already part of a complete transfer.
  completedTransfer;

  /// Returns a user-friendly error message.
  String message() {
    switch (this) {
      case TransferLinkConflict.completedTransfer:
        return 'The selected transaction is already part of a complete transfer. '
            'You need to unlink it first before you can use it here.';
      case TransferLinkConflict.sameSigns:
        return 'The selected transaction has the same sign as the source transaction. '
            'Transfers must have one income and one expense transaction.';
    }
  }

  /// Returns a user-friendly title.
  String title() {
    switch (this) {
      case TransferLinkConflict.completedTransfer:
        return 'Cannot link this transaction';
      case TransferLinkConflict.sameSigns:
        return 'Invalid transfer link';
    }
  }

  Future<void> showAsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title()),
        content: Text(message()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
