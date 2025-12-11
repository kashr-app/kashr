import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/turnover_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _DialogState { checkingUsage, confirmingDeletion, deleting, blocked }

/// A dialog that checks with all registered tag listeners before allowing
/// tag deletion, then performs the deletion.
///
/// Flow:
/// 1. Shows loading while checking all listeners
/// 2. If blocked: shows blocking reasons and actions, user can cancel
/// 3. If allowed: shows confirmation, user can confirm or cancel
/// 4. On confirm: performs deletion with loading state
/// 5. Returns true if tag was deleted, false/null otherwise
class TagDeletionDialog extends StatefulWidget {
  final Tag tag;

  const TagDeletionDialog({super.key, required this.tag});

  static Future<bool?> show(BuildContext context, {required Tag tag}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TagDeletionDialog(tag: tag),
    );
  }

  @override
  State<TagDeletionDialog> createState() => _TagDeletionDialogState();
}

class _TagDeletionDialogState extends State<TagDeletionDialog> {
  _DialogState _state = _DialogState.checkingUsage;
  List<BeforeTagDeleteResult> _results = [];
  String? _deletionError;

  @override
  void initState() {
    super.initState();
    _checkListeners();
  }

  /// Public method to trigger a refresh of the listener checks.
  /// This allows suggested actions to refresh the dialog state after
  /// performing remediation actions.
  void refreshListeners() => _checkListeners();

  Future<void> _checkListeners() async {
    final results = <BeforeTagDeleteResult>[];
    final tagListeners = context.read<TurnoverModule>().tagListeners;

    for (final listener in tagListeners) {
      try {
        final result = await listener.onBeforeTagDelete(
          widget.tag,
          recheckStatus: refreshListeners,
        );
        results.add(result);
      } catch (e) {
        results.add(
          BeforeTagDeleteResult(
            canProceed: false,
            blockingReason: 'Error checking deletion: ${e.toString()}',
            buildSuggestedActions: null,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _state = _canDelete
            ? _DialogState.confirmingDeletion
            : _DialogState.blocked;
      });
    }
  }

  bool get _canDelete => _results.every((r) => r.canProceed);

  List<BeforeTagDeleteResult> get _blockingResults =>
      _results.where((r) => !r.canProceed).toList();

  Future<void> _performDeletion() async {
    setState(() {
      _state = _DialogState.deleting;
      _deletionError = null;
    });

    try {
      await context.read<TagCubit>().deleteTag(widget.tag.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deletionError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _DialogState.checkingUsage:
        return _buildLoadingDialog(
          context,
          'Checking Tag Usage',
          'Checking if "${widget.tag.name}" can be deleted...',
        );
      case _DialogState.confirmingDeletion:
        return _buildConfirmationDialog(context);
      case _DialogState.deleting:
        return _buildLoadingDialog(
          context,
          'Deleting Tag',
          'Deleting "${widget.tag.name}"...',
        );
      case _DialogState.blocked:
        return _buildBlockedDialog(context);
    }
  }

  Widget _buildLoadingDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildConfirmationDialog(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Delete Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${widget.tag.name}"?'),
          if (_deletionError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to delete: $_deletionError',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _performDeletion,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _buildBlockedDialog(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Cannot Delete Tag'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The tag "${widget.tag.name}" cannot be deleted because:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ..._blockingResults.expand((result) {
              return [
                _BlockingReasonCard(result: result),
                const SizedBox(height: 12),
              ];
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _BlockingReasonCard extends StatelessWidget {
  final BeforeTagDeleteResult result;

  const _BlockingReasonCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.block,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.blockingReason ?? 'Cannot proceed with deletion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (result.buildSuggestedActions != null) ...[
            const SizedBox(height: 16),
            ...result.buildSuggestedActions!(context),
          ],
        ],
      ),
    );
  }
}
