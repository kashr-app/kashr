import 'dart:async';
import 'dart:developer' as developer;

import 'package:kashr/core/color_utils.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/turnover_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Listens to tag deletion events and handles associated TagTurnovers.
///
/// When a tag with TagTurnovers is about to be deleted, this listener provides:
/// - Information about how many TagTurnovers are affected
/// - Actions to delete TagTurnovers or move them to another tag
class TagTurnoverTagListener extends TagListener {
  final TagTurnoverRepository tagTurnoverRepository;

  TagTurnoverTagListener({required this.tagTurnoverRepository});

  @override
  Future<BeforeTagDeleteResult> onBeforeTagDelete(
    Tag tag, {
    required VoidCallback recheckStatus,
  }) async {
    try {
      final tagTurnovers = await tagTurnoverRepository.getByTag(tag.id);

      if (tagTurnovers.isEmpty) {
        return BeforeTagDeleteResult(
          canProceed: true,
          blockingReason: null,
          buildSuggestedActions: null,
        );
      }

      return BeforeTagDeleteResult(
        canProceed: false,
        blockingReason:
            'This tag has ${tagTurnovers.length} tag turnover${tagTurnovers.length == 1 ? '' : 's'} that must be handled first.',
        buildSuggestedActions: (context) => [
          _buildInfoSection(context, tagTurnovers.length),
          const SizedBox(height: 12),
          _buildActionButtons(context, tag, recheckStatus),
        ],
      );
    } catch (e, s) {
      developer.log(
        'Failed to check tag turnovers for tag ${tag.id}',
        error: e,
        stackTrace: s,
      );
      return BeforeTagDeleteResult(
        canProceed: false,
        blockingReason: 'Error checking tag turnovers: $e',
        buildSuggestedActions: null,
      );
    }
  }

  Widget _buildInfoSection(BuildContext context, int count) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you can do:',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoBullet(
          context,
          'Delete the tag turnover${count == 1 ? '' : 's'} '
          '(turnover amounts become unallocated)',
        ),
        const SizedBox(height: 4),
        _buildInfoBullet(
          context,
          'Move the tag turnover${count == 1 ? '' : 's'} to another tag',
        ),
      ],
    );
  }

  Widget _buildInfoBullet(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.circle,
            size: 6,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Tag tag,
    VoidCallback recheckStatus,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () =>
              _handleDeleteTagTurnovers(context, tag, recheckStatus),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete Tag Turnovers'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _handleMoveToAnotherTag(context, tag, recheckStatus),
          icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
          label: const Text('Move to Another Tag'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onErrorContainer,
            side: BorderSide(color: theme.colorScheme.onErrorContainer),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDeleteTagTurnovers(
    BuildContext context,
    Tag tag,
    VoidCallback recheckStatus,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag Turnovers?'),
        content: const Text(
          'This will delete all tag turnovers for this tag. '
          'The turnover amounts will become unallocated.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Return if user cancelled
    if (confirmed != true) return;

    try {
      // Show loading indicator
      if (context.mounted) {
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          ),
        );
      }

      final count = await tagTurnoverRepository.deleteAllByTagId(tag.id);

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted $count tag turnover${count == 1 ? '' : 's'}',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      recheckStatus();
    } catch (e, s) {
      developer.log('Failed to delete tag turnovers', error: e, stackTrace: s);

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete tag turnovers: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleMoveToAnotherTag(
    BuildContext context,
    Tag currentTag,
    VoidCallback refreshDialog,
  ) async {
    // Get all available tags except the current one
    final tagCubit = context.read<TagCubit>();
    final allTags = tagCubit.state.tags
        .where((tag) => tag.id != currentTag.id)
        .toList();

    if (allTags.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other tags available to move to')),
        );
      }
      return;
    }

    // Show tag selection dialog
    final selectedTag = await showDialog<Tag>(
      context: context,
      builder: (context) =>
          _TagSelectionDialog(tags: allTags, title: 'Move Tag Turnovers to...'),
    );

    if (selectedTag == null) return;

    if (!context.mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Tag Turnovers?'),
        content: Text(
          'This will move all tag turnovers from "${currentTag.name}" to "${selectedTag.name}".\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    // Return if user cancelled
    if (confirmed != true) return;

    if (!context.mounted) return;
    try {
      // Show loading indicator
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        ),
      );

      final count = await tagTurnoverRepository.updateTagByTagId(
        currentTag.id,
        selectedTag.id,
      );

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved $count tag turnover${count == 1 ? '' : 's'} to "${selectedTag.name}"',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      // Refresh the tag deletion dialog
      refreshDialog();
    } catch (e, s) {
      developer.log('Failed to move tag turnovers', error: e, stackTrace: s);

      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move tag turnovers: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Dialog for selecting a tag from a list of tags.
class _TagSelectionDialog extends StatelessWidget {
  final List<Tag> tags;
  final String title;

  const _TagSelectionDialog({required this.tags, required this.title});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tags.length,
          itemBuilder: (context, index) {
            final tag = tags[index];
            final tagColor = ColorUtils.parseColor(tag.color) ?? Colors.grey;
            return ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tagColor,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(tag.name),
              onTap: () => Navigator.of(context).pop(tag),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
