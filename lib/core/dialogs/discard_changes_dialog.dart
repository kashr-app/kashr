import 'package:flutter/material.dart';

/// A dialog that asks the user to confirm discarding unsaved changes.
class DiscardChangesDialog {
  DiscardChangesDialog._();

  /// Shows a dialog asking the user to confirm discarding changes.
  ///
  /// Returns `true` if the user wants to discard changes, `false` if they
  /// want to cancel, or `null` if the dialog is dismissed.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
