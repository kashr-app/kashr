import 'package:flutter/material.dart';
import 'package:kashr/core/widgets/sheet_grabber.dart';

/// Shows how transactions are entered by hand, and offers to do it now.
///
/// The two buttons it describes are the ones beside the one the user just
/// tapped, so naming them is only half the answer; the rows here also do the
/// thing, which is what makes this a route rather than a signpost.
Future<void> showManualEntryExplainer(
  BuildContext context, {
  required VoidCallback onLogTransaction,
  required VoidCallback onLogTransfer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      void close(VoidCallback andThen) {
        Navigator.of(sheetContext).pop();
        andThen();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 16),
              Text(
                'Enter them yourself',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'These two buttons sit either side of the one you just '
                'tapped.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add),
                title: const Text('Log a transaction'),
                subtitle: const Text('Money in or out of one account.'),
                onTap: () => close(onLogTransaction),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Log a transfer'),
                subtitle: const Text('Money between two of your accounts.'),
                onTap: () => close(onLogTransfer),
              ),
            ],
          ),
        ),
      );
    },
  );
}
