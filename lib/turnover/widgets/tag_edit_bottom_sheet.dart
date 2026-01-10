import 'package:kashr/core/color_utils.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A bottom sheet for creating or editing a tag.
///
/// Shows a form with fields for name, color, and semantic type.
/// Returns the created/updated [Tag] or null if cancelled.
class TagEditBottomSheet extends StatefulWidget {
  final Tag? tag;
  final String? initialName;

  /// [initialSemantic] might be overwritten by [enforcedSemantic]
  final TagSemantic? initialSemantic;

  /// [enforcedSemantic] precedes [initialSemantic] and [tag.semantic]
  final TagSemantic? Function()? enforcedSemantic;

  const TagEditBottomSheet({
    super.key,
    this.tag,
    this.initialName,
    this.initialSemantic,
    this.enforcedSemantic,
  });

  /// Shows the bottom sheet and returns the created/edited tag or null if
  /// cancelled.
  static Future<Tag?> show(
    BuildContext context, {
    Tag? tag,
    String? initialName,
    TagSemantic? initialSemantic,
    TagSemantic? Function()? enforcedSemantic,
  }) {
    return showModalBottomSheet<Tag>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagEditBottomSheet(
        tag: tag,
        initialName: initialName,
        initialSemantic: initialSemantic,
        enforcedSemantic: enforcedSemantic,
      ),
    );
  }

  @override
  State<TagEditBottomSheet> createState() => _TagEditBottomSheetState();
}

class _TagEditBottomSheetState extends State<TagEditBottomSheet> {
  late TextEditingController _nameController;
  Color? _selectedColor;
  TagSemantic? _selectedSemantic;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.tag?.name ?? widget.initialName ?? '',
    );
    _selectedColor = ColorUtils.parseColor(widget.tag?.color);
    _selectedSemantic =
        widget.enforcedSemantic?.call() ??
        widget.tag?.semantic ??
        widget.initialSemantic;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showTransferExplanationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('About Transfer Tags & Savings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogSection(
              icon: Icons.swap_horiz,
              title: 'What are Transfer tags?',
              description:
                  'Transfer tags are for moving money between your accounts. '
                  'These transactions don\'t affect your income or expenses.',
            ),
            const SizedBox(height: 16),
            _DialogSection(
              icon: Icons.savings_outlined,
              title: 'Why not for Savings?',
              description:
                  'In Kashr, savings aren\'t separate accounts. You allocate '
                  'savings across your existing accounts (one or multiple).',
            ),
            const SizedBox(height: 16),
            Text(
              'Have a dedicated savings account?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _AlternativeOption(
              number: '1',
              description: 'Simply check your account balance or',
            ),
            const SizedBox(height: 8),
            _AlternativeOption(
              number: '2',
              description:
                  'Create a savings tag and use savings adjustments to '
                  'allocate part of your account balance as savings.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Tag' : 'Create Tag',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Color',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableColors.map((color) {
                            final isSelected =
                                _selectedColor?.toARGB32() == color.toARGB32();
                            return InkWell(
                              onTap: () =>
                                  setState(() => _selectedColor = color),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color:
                                            ColorUtils.getContrastingTextColor(
                                              color,
                                            ),
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<TagSemantic?>(
                          initialValue: _selectedSemantic,
                          decoration: const InputDecoration(
                            labelText: 'Tag Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Normal (Income/Expense)'),
                            ),
                            DropdownMenuItem(
                              value: TagSemantic.transfer,
                              child: Text('Transfer'),
                            ),
                          ],
                          onChanged: widget.enforcedSemantic != null
                              ? null
                              : (value) =>
                                    setState(() => _selectedSemantic = value),
                        ),
                        const SizedBox(height: 8),
                        _HelperTextWithMoreHelp(
                          onHelpPressed: () =>
                              _showTransferExplanationDialog(context),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _nameController.text.trim().isEmpty
                            ? null
                            : () async {
                                final name = _nameController.text.trim();
                                final colorString = _selectedColor != null
                                    ? ColorUtils.colorToString(_selectedColor!)
                                    : null;

                                final tag = Tag(
                                  id: widget.tag?.id ?? const Uuid().v4obj(),
                                  name: name,
                                  color: colorString,
                                  semantic:
                                      widget.enforcedSemantic?.call() ??
                                      _selectedSemantic,
                                );

                                if (isEditing) {
                                  await context.read<TagCubit>().updateTag(tag);
                                } else {
                                  await context.read<TagCubit>().createTag(tag);
                                }

                                if (context.mounted) {
                                  Navigator.of(context).pop(tag);
                                }
                              },
                        child: Text(isEditing ? 'Save' : 'Create'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HelperTextWithMoreHelp extends StatelessWidget {
  final VoidCallback onHelpPressed;

  const _HelperTextWithMoreHelp({required this.onHelpPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Transfer tags exclude transactions from cashflow calculations '
            'and cannot be used for savings.',
            style: helperStyle,
          ),
        ),
        InkWell(
          onTap: onHelpPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.help_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _DialogSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlternativeOption extends StatelessWidget {
  final String number;
  final String description;

  const _AlternativeOption({required this.number, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(description, style: theme.textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}
