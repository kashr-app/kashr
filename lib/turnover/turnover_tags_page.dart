import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class TurnoverTagsRoute extends GoRouteData with $TurnoverTagsRoute {
  final String turnoverId;
  const TurnoverTagsRoute({required this.turnoverId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (context) => TurnoverTagsCubit(
        context.read<TagTurnoverRepository>(),
        context.read<TagRepository>(),
        context.read<TurnoverRepository>(),
      )..loadTurnover(UuidValue.fromString(turnoverId)),
      child: TurnoverTagsPage(turnoverId: turnoverId),
    );
  }
}

class TurnoverTagsPage extends StatelessWidget {
  final String turnoverId;
  const TurnoverTagsPage({required this.turnoverId, super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final cubit = context.read<TurnoverTagsCubit>();
        if (!cubit.state.isDirty) {
          Navigator.of(context).pop();
          return;
        }

        final shouldDiscard = await _showDiscardDialog(context);
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Turnover Tags'),
        ),
        body: BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
        builder: (context, state) {
          final turnover = state.turnover;
          if (turnover == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Turnover information card
              _TurnoverInfoCard(turnover: turnover),

              // Tag turnovers list
              Expanded(
                child: state.tagTurnovers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No tags assigned yet'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _showAddTagDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Tag'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.tagTurnovers.length,
                        itemBuilder: (context, index) {
                          final tagTurnover = state.tagTurnovers[index];
                          return _TagTurnoverItem(
                            tagTurnoverWithTag: tagTurnover,
                            maxAmountScaled:
                                decimalScale(turnover.amountValue) ?? 0,
                            currencyUnit: turnover.amountUnit,
                          );
                        },
                      ),
              ),

              // Status message and save button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildStatusMessage(context, state, turnover),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _showAddTagDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Tag'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: (state.isAmountExceeded || !state.isDirty)
                                ? null
                                : () async {
                                    await context
                                        .read<TurnoverTagsCubit>()
                                        .saveAll();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context) {
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

  void _showAddTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddTagDialog(
        cubit: context.read<TurnoverTagsCubit>(),
      ),
    );
  }

  Widget _buildStatusMessage(
    BuildContext context,
    TurnoverTagsState state,
    Turnover turnover,
  ) {
    final theme = Theme.of(context);
    final currency = Currency.currencyFrom(turnover.amountUnit);

    final totalAbsolute = state.totalTagAmount.abs();
    final turnoverAbsolute = turnover.amountValue.abs();
    final difference = (totalAbsolute - turnoverAbsolute).abs();

    final isExceeded = state.isAmountExceeded;
    final isPerfect = totalAbsolute == turnoverAbsolute;

    if (isPerfect) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Perfectly allocated!',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (isExceeded) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Exceeds by ${currency.format(difference, decimalDigits: 2)}',
              style: TextStyle(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Remaining: ${currency.format(difference, decimalDigits: 2)}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _TurnoverInfoCard extends StatelessWidget {
  final Turnover turnover;

  const _TurnoverInfoCard({required this.turnover});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              turnover.counterPart ?? '(Unknown)',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              turnover.purpose,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  turnover.formatDate() ?? '',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  turnover.format(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagTurnoverItem extends StatelessWidget {
  final TagTurnoverWithTag tagTurnoverWithTag;
  final int maxAmountScaled;
  final String currencyUnit;

  const _TagTurnoverItem({
    required this.tagTurnoverWithTag,
    required this.maxAmountScaled,
    required this.currencyUnit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagTurnover = tagTurnoverWithTag.tagTurnover;
    final tag = tagTurnoverWithTag.tag;
    final amountScaled = decimalScale(tagTurnover.amountValue) ?? 0;

    final color = tag.color != null ? _parseColor(tag.color!) : null;

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
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color ?? theme.colorScheme.primaryContainer,
                  child: Text(
                    tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      color: color != null
                          ? _getContrastingTextColor(color)
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
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
            ),
            const SizedBox(height: 8),
            Slider(
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
            ),
            BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
              builder: (context, state) {
                final exceededAmountScaled = decimalScale(state.exceededAmount) ?? 0;
                final isExceeded = state.isAmountExceeded;
                final totalAbsolute = state.totalTagAmount.abs();
                final turnoverAbsolute = (state.turnover?.amountValue.abs()) ?? Decimal.zero;
                final isPerfect = totalAbsolute == turnoverAbsolute;

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        tagTurnover.format(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isPerfect && (isExceeded || currentAbsolute < maxAbsolute))
                      IconButton(
                        icon: Icon(
                          isExceeded ? Icons.remove : Icons.add,
                          size: 20,
                        ),
                        tooltip: isExceeded
                            ? 'Reduce by exceeded amount'
                            : 'Fill remaining',
                        onPressed: () {
                          final cubit = context.read<TurnoverTagsCubit>();
                          int newAbsoluteAmount;

                          if (isExceeded) {
                            // Reduce by exceeded amount, but at most to 0
                            newAbsoluteAmount = (currentAbsolute - exceededAmountScaled).clamp(0, maxAbsolute);
                          } else {
                            // Calculate remaining uncovered amount
                            final totalTagAmountScaled = decimalScale(state.totalTagAmount) ?? 0;
                            final remainingScaled = maxAbsolute - totalTagAmountScaled.abs();
                            // Add remaining to current amount, clamped to max
                            newAbsoluteAmount = (currentAbsolute + remainingScaled).clamp(0, maxAbsolute);
                          }

                          final signedValue = isNegative ? -newAbsoluteAmount : newAbsoluteAmount;
                          cubit.updateTagTurnoverAmount(tagTurnover.id!, signedValue);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final result = await AmountDialog.show(
                          context,
                          currencyUnit: currencyUnit,
                          maxAmountScaled: maxAmountScaled.abs(),
                          initialAmountScaled: amountScaled.abs(),
                        );

                        if (result != null && context.mounted) {
                          // Apply the sign of the turnover to the result
                          final signedResult = isNegative ? -result : result;
                          context
                              .read<TurnoverTagsCubit>()
                              .updateTagTurnoverAmount(tagTurnover.id!, signedResult);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            _NoteField(
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

  Color? _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return null;
    }
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _NoteField extends StatefulWidget {
  final String? note;
  final void Function(String?) onNoteChanged;

  const _NoteField({
    required this.note,
    required this.onNoteChanged,
  });

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = widget.note != null && widget.note!.isNotEmpty;

    if (!_isEditing && !hasNote) {
      return TextButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.note_add, size: 16),
        label: const Text('Add note'),
      );
    }

    if (!_isEditing && hasNote) {
      return InkWell(
        onTap: () => setState(() => _isEditing = true),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.note, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            final note = _controller.text.trim();
            widget.onNoteChanged(note.isEmpty ? null : note);
            setState(() => _isEditing = false);
          },
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _controller.text = widget.note ?? '';
            setState(() => _isEditing = false);
          },
        ),
      ],
    );
  }
}

class _AddTagDialog extends StatefulWidget {
  final TurnoverTagsCubit cubit;

  const _AddTagDialog({required this.cubit});

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  late TextEditingController _searchController;
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTags = widget.cubit.state.availableTags;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredTags = widget.cubit.searchTags(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchQuery = _searchController.text.trim();
    final exactMatch = _filteredTags.any(
      (tag) => tag.name.toLowerCase() == searchQuery.toLowerCase(),
    );

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Tag',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search or create tag',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            if (searchQuery.isNotEmpty && !exactMatch)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.add),
                ),
                title: Text('Create "$searchQuery"'),
                onTap: () async {
                  final newTag = await widget.cubit.createAndAddTag(
                    searchQuery,
                    null,
                  );
                  if (newTag != null && context.mounted) {
                    widget.cubit.addTag(newTag);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
            const Divider(),
            Flexible(
              child: _filteredTags.isEmpty
                  ? const Center(child: Text('No tags found'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        final color = tag.color != null
                            ? _parseColor(tag.color!)
                            : null;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                color ?? theme.colorScheme.primaryContainer,
                            child: Text(
                              tag.name.isNotEmpty
                                  ? tag.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: color != null
                                    ? _getContrastingTextColor(color)
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(tag.name),
                          onTap: () {
                            widget.cubit.addTag(tag);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return null;
    }
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
