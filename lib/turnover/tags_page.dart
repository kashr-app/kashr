import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/dialogs/merge_final_confirmation_dialog.dart';
import 'package:finanalyzer/turnover/dialogs/merge_tags_preview_dialog.dart';
import 'package:finanalyzer/turnover/dialogs/tag_deletion_dialog.dart';
import 'package:finanalyzer/turnover/dialogs/tag_picker_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_edit_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TagsRoute extends GoRouteData with $TagsRoute {
  const TagsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const TagsPage();
  }
}

/// Page for viewing, creating, and editing tags.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: SafeArea(
        child: BlocBuilder<TagCubit, TagState>(
          builder: (context, state) {
            if (state.status.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status.isError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.errorMessage ?? 'An error occurred',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.read<TagCubit>().loadTags(
                        invalidateCache: true,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state.tags.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No tags yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showTagDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Tag'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: state.tags.length,
              itemBuilder: (context, index) {
                final tag = state.tags[index];
                return _TagListItem(
                  tag: tag,
                  onTap: () => _showTagDialog(context, tag: tag),
                  onDelete: () async => await _confirmDelete(context, tag),
                  onMerge: () => _showMergeDialog(context, tag),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTagDialog(BuildContext context, {Tag? tag}) {
    TagEditBottomSheet.show(context, tag: tag);
  }

  Future<void> _confirmDelete(BuildContext context, Tag tag) async {
    await TagDeletionDialog.show(context, tag: tag);
  }

  Future<void> _showMergeDialog(BuildContext context, Tag sourceTag) async {
    // Step 1: Show tag picker dialog to select target tag
    final targetTag = await TagPickerDialog.show(
      context,
      excludeTagIds: {sourceTag.id},
      title: 'Select Target Tag',
      subtitle: 'Merge "${sourceTag.name}" into:',
    );

    if (targetTag == null || !context.mounted) {
      return;
    }

    // Step 2: Fetch savings info for both tags
    final savingsRepo = context.read<SavingsRepository>();
    final savingsBalanceService = context.read<SavingsBalanceService>();

    final sourceSavings = await savingsRepo.getByTagId(sourceTag.id);
    final targetSavings = await savingsRepo.getByTagId(targetTag.id);

    // Calculate balances using the SavingsBalanceService
    final sourceBalance = sourceSavings != null
        ? await savingsBalanceService.calculateTotalBalance(sourceSavings)
        : null;
    final targetBalance = targetSavings != null
        ? await savingsBalanceService.calculateTotalBalance(targetSavings)
        : null;

    if (!context.mounted) return;

    // Step 3: Show merge preview dialog with savings implications
    final previewResult = await MergeTagsPreviewDialog.show(
      context,
      sourceTag: sourceTag,
      targetTag: targetTag,
      sourceSavings: sourceSavings,
      targetSavings: targetSavings,
      sourceBalance: sourceBalance,
      targetBalance: targetBalance,
    );

    if (previewResult == null || !previewResult.proceed || !context.mounted) {
      return;
    }

    // Step 4: Show final confirmation dialog
    final confirmed = await MergeFinalConfirmationDialog.show(
      context,
      sourceTag: sourceTag,
      targetTag: targetTag,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    // Step 5: Execute the merge
    await context.read<TagCubit>().mergeTags(sourceTag.id, targetTag.id);

    if (!context.mounted) return;

    // Step 6: Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${sourceTag.name}" merged into "${targetTag.name}"'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _TagListItem extends StatelessWidget {
  final Tag tag;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMerge;

  const _TagListItem({
    required this.tag,
    required this.onTap,
    required this.onDelete,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ColorUtils.parseColor(tag.color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color ?? theme.colorScheme.primaryContainer,
        child: Text(
          tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color != null
                ? ColorUtils.getContrastingTextColor(color)
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(tag.name),
      subtitle: tag.isTransfer ? const Text('Transfer') : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'merge':
              onMerge();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'merge',
            child: Row(
              children: [
                Icon(Icons.merge),
                SizedBox(width: 12),
                Text('Merge with...'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline),
                SizedBox(width: 12),
                Text('Delete'),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
