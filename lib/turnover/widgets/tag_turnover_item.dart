import 'package:kashr/turnover/cubit/turnover_tags_cubit.dart';
import 'package:kashr/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/widgets/note_field.dart';
import 'package:kashr/turnover/widgets/tag_amount_controls.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:kashr/turnover/widgets/transfer_issue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays a tag turnover item with amount allocation controls.
///
/// Shows the tag name, avatar, slider for amount allocation, and note field.
class TagTurnoverItem extends StatelessWidget {
  final TagTurnover tagTurnover;
  final Tag tag;
  final int maxAmountScaled;
  final String currencyUnit;
  final TransferWithDetails? transferWithDetails;

  const TagTurnoverItem({
    required this.tagTurnover,
    required this.tag,
    required this.maxAmountScaled,
    required this.currencyUnit,
    this.transferWithDetails,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, tagTurnover),
            const SizedBox(height: 8),
            TagAmountControls(
              tagTurnover: tagTurnover,
              maxAmountScaled: maxAmountScaled,
              currencyUnit: currencyUnit,
            ),
            const SizedBox(height: 8),
            NoteField(
              note: tagTurnover.note,
              onNoteChanged: (note) {
                context.read<TurnoverTagsCubit>().updateTagTurnoverNote(
                  tagTurnover.id,
                  note,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TagTurnover tagTurnover) {
    final theme = Theme.of(context);

    final isTransferTag = tag.isTransfer;
    final hasTransfer = transferWithDetails != null;
    final isTransfer = isTransferTag || hasTransfer;

    final isUnlinkedTransfer = isTransferTag && !hasTransfer;
    final transferNeedsReview = transferWithDetails?.needsReview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _onTap(context),
          leading: TagAvatar(tag: tag),
          title: Text(tag.name, style: theme.textTheme.titleMedium),
          subtitle: Text(
            dateFormat.format(tagTurnover.bookingDate),
            style: theme.textTheme.bodySmall,
          ),
          trailing: _buildTagTurnoverPopUpMenu(
            context,
            tagTurnover,
            isTransfer: isTransfer,
          ),
        ),
        // Transfer badges
        if (isTransfer) ...[
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            children: [
              TransferBadge.badge(),
              if (isUnlinkedTransfer) ...[
                const SizedBox(width: 8),
                TransferBadge.unlinked(),
              ] else if (transferNeedsReview != null) ...[
                const SizedBox(width: 8),
                TransferBadge.needsReviewDetailed(transferNeedsReview),
              ],
            ],
          ),
        ],
      ],
    );
  }

  PopupMenuButton<TagTurnoverPopUpMenu> _buildTagTurnoverPopUpMenu(
    BuildContext context,
    TagTurnover tagTurnover, {
    required bool isTransfer,
  }) {
    return PopupMenuButton<TagTurnoverPopUpMenu>(
      initialValue: null,
      onSelected: (TagTurnoverPopUpMenu item) {
        switch (item) {
          case TagTurnoverPopUpMenu.edit:
            _onTap(context);
          case TagTurnoverPopUpMenu.editTransfer:
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(
                  'Transfer links can\'t be edited here, because the edits are temporary until saved.'
                  ' Please save changes and then review the transfer link from the transfers review page.\n\n'
                  'If the Transfer has a problem it will be highlighted on the home screen.'
                  ' You can view all transfers via Settings > Transfers',
                ),
                actions: [
                  TextButton(
                    child: Text('Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          case TagTurnoverPopUpMenu.delete:
            context.read<TurnoverTagsCubit>().deleteTagTurnover(tagTurnover.id);
          case TagTurnoverPopUpMenu.unallocate:
            context.read<TurnoverTagsCubit>().unallocateTagTurnover(tagTurnover);
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: TagTurnoverPopUpMenu.unallocate,
          child: Row(
            children: [
              Icon(Icons.remove),
              SizedBox(width: 8),
              Text('Remove from turnover'),
            ],
          ),
        ),
        if (isTransfer)
          const PopupMenuItem(
            value: TagTurnoverPopUpMenu.editTransfer,
            child: Row(
              children: [
                Icon(Icons.link),
                SizedBox(width: 8),
                Text('Edit Transfer Link'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: TagTurnoverPopUpMenu.edit,
          child: Row(
            children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
          ),
        ),
        const PopupMenuItem(
          value: TagTurnoverPopUpMenu.delete,
          child: Row(
            children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')],
          ),
        ),
      ],
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final result = await TagTurnoverEditorDialog.show(
      context,
      tagTurnover: tagTurnover,
    );

    if (result == null || !context.mounted) return;
    final cubit = context.read<TurnoverTagsCubit>();
    switch (result) {
      case EditTagTurnoverUpdated():
        cubit.updateTagTurnover(result.tagTurnover);
      case EditTagTurnoverDeleted():
        cubit.deleteTagTurnover(tagTurnover.id);
    }
  }
}

enum TagTurnoverPopUpMenu { unallocate, editTransfer, edit, delete }
