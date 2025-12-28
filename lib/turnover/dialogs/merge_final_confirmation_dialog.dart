import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// Final confirmation dialog before executing a tag merge.
///
/// Simple "are you sure" dialog that emphasizes the irreversible nature
/// of the merge operation.
class MergeFinalConfirmationDialog extends StatelessWidget {
  final Tag sourceTag;
  final Tag targetTag;

  const MergeFinalConfirmationDialog({
    super.key,
    required this.sourceTag,
    required this.targetTag,
  });

  /// Shows the dialog and returns true if user confirms the merge.
  static Future<bool> show(
    BuildContext context, {
    required Tag sourceTag,
    required Tag targetTag,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MergeFinalConfirmationDialog(
        sourceTag: sourceTag,
        targetTag: targetTag,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        size: 48,
      ),
      scrollable: true,
      title: const Text('Merge Tags?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This action cannot be undone.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'All transactions from "${sourceTag.name}" will be moved to "${targetTag.name}".'
            ' The tag "${sourceTag.name}" will be permanently deleted.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Merge'),
        ),
      ],
    );
  }
}
