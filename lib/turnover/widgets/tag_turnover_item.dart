import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/widgets/note_field.dart';
import 'package:finanalyzer/turnover/widgets/tag_amount_controls.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:finanalyzer/turnover/widgets/transfer_issue_badge.dart';
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
  final VoidCallback? onTransferAction;

  const TagTurnoverItem({
    required this.tagTurnover,
    required this.tag,
    required this.maxAmountScaled,
    required this.currencyUnit,
    this.transferWithDetails,
    this.onTransferAction,
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
          trailing: IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Unlink from turnover',
            onPressed: () {
              context.read<TurnoverTagsCubit>().unlinkTagTurnover(tagTurnover);
            },
          ),
        ),
        // Transfer badges
        if (isTransferTag || hasTransfer) ...[
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
              if (onTransferAction != null)
                TextButton.icon(
                  onPressed: onTransferAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    isUnlinkedTransfer ? Icons.link : Icons.open_in_new,
                    size: 16,
                  ),
                  label: Text(
                    isUnlinkedTransfer ? 'Link Transfer' : 'View Transfer',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ],
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
        cubit.updateTagTurnover(tagTurnover);
      case EditTagTurnoverDeleted():
        cubit.removeTagTurnover(tagTurnover.id);
    }
  }
}
