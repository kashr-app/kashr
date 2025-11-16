import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/widgets/note_field.dart';
import 'package:finanalyzer/turnover/widgets/tag_amount_controls.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays a tag turnover item with amount allocation controls.
///
/// Shows the tag name, avatar, slider for amount allocation, and note field.
class TagTurnoverItem extends StatelessWidget {
  final TagTurnoverWithTag tagTurnoverWithTag;
  final int maxAmountScaled;
  final String currencyUnit;

  const TagTurnoverItem({
    required this.tagTurnoverWithTag,
    required this.maxAmountScaled,
    required this.currencyUnit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagTurnover = tagTurnoverWithTag.tagTurnover;
    final tag = tagTurnoverWithTag.tag;
    final amountScaled = decimalScale(tagTurnover.amountValue) ?? 0;

    // Configure slider to work with absolute values for better UX
    // Left (0) = no allocation, Right (max) = full turnover allocation
    final bool isNegative = maxAmountScaled < 0;
    final int maxAbsolute = maxAmountScaled.abs();
    final int currentAbsolute = amountScaled.abs();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme, tag, tagTurnover),
            const SizedBox(height: 8),
            _buildSlider(
              context,
              tagTurnover,
              currentAbsolute,
              maxAbsolute,
              isNegative,
            ),
            TagAmountControls(
              tagTurnover: tagTurnover,
              maxAmountScaled: maxAmountScaled,
              currencyUnit: currencyUnit,
            ),
            const SizedBox(height: 8),
            NoteField(
              note: tagTurnover.note,
              onNoteChanged: (note) {
                context
                    .read<TurnoverTagsCubit>()
                    .updateTagTurnoverNote(tagTurnover.id!, note);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    tag,
    tagTurnover,
  ) {
    return Row(
      children: [
        TagAvatar(tag: tag),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tag.name,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            context
                .read<TurnoverTagsCubit>()
                .removeTagTurnover(tagTurnover.id!);
          },
        ),
      ],
    );
  }

  Widget _buildSlider(
    BuildContext context,
    tagTurnover,
    int currentAbsolute,
    int maxAbsolute,
    bool isNegative,
  ) {
    return Slider(
      value: currentAbsolute.toDouble(),
      min: 0,
      max: maxAbsolute.toDouble(),
      divisions: maxAbsolute > 0 ? maxAbsolute : 1,
      label: tagTurnover.format(),
      onChanged: (value) {
        // Apply the sign back when updating
        final signedValue = isNegative ? -value.toInt() : value.toInt();
        context
            .read<TurnoverTagsCubit>()
            .updateTagTurnoverAmount(
              tagTurnover.id!,
              signedValue,
            );
      },
    );
  }
}
