import 'package:kashr/turnover/dialogs/tag_picker_dialog.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// Mode for the batch tag dialog.
enum BatchTagMode { add, remove }

/// Result returned from the batch tag dialog.
class BatchTagResult {
  const BatchTagResult(
    this.tag, {
    required this.mode,
    this.deleteTaggings = false,
  });

  final Tag tag;
  final BatchTagMode mode;
  final bool deleteTaggings;
}

/// Dialog for selecting a tag to add or remove from multiple turnovers.
class BatchTagDialog {
  static Future<BatchTagResult?> show(
    BuildContext context, {
    required int affectedTurnoversCount,
    required BatchTagMode mode,
  }) async {
    final isAdd = mode == BatchTagMode.add;

    final selectedTag = await TagPickerDialog.show(
      context,
      title: isAdd ? 'Select Tag to Add' : 'Select Tag to Remove',
    );

    if (selectedTag != null && context.mounted) {
      return isAdd
          ? await _showAddConfirmation(
              context,
              affectedTurnoversCount,
              selectedTag,
            )
          : await _showRemoveConfirmation(
              context,
              affectedTurnoversCount,
              selectedTag,
            );
    }
    return null;
  }

  static Future<BatchTagResult?> _showAddConfirmation(
    BuildContext context,
    int affectedTurnoversCount,
    Tag tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Tag'),
        content: Text(
          'Add "${tag.name}" to $affectedTurnoversCount turnovers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    return confirmed == true
        ? BatchTagResult(tag, mode: BatchTagMode.add)
        : null;
  }

  static Future<BatchTagResult?> _showRemoveConfirmation(
    BuildContext context,
    int affectedTurnoversCount,
    Tag tag,
  ) async {
    final deleteTaggings = await showDialog<bool?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove "${tag.name}" from $affectedTurnoversCount turnovers?',
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose how to handle the taggings:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Unallocate Only'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Completely'),
          ),
        ],
      ),
    );

    return deleteTaggings != null
        ? BatchTagResult(
            tag,
            mode: BatchTagMode.remove,
            deleteTaggings: deleteTaggings,
          )
        : null;
  }
}
