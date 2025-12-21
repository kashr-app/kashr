import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/source_card.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class PendingTurnoversRoute extends GoRouteData with $PendingTurnoversRoute {
  const PendingTurnoversRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const PendingTurnoversPage();
  }
}

class PendingTurnoversPage extends StatefulWidget {
  const PendingTurnoversPage({super.key});

  @override
  State<PendingTurnoversPage> createState() => _PendingTurnoversPageState();
}

class _PendingTurnoversPageState extends State<PendingTurnoversPage> {
  List<TagTurnover>? _pendingTurnovers;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingTurnovers();
  }

  Future<void> _loadPendingTurnovers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();

      final unmatched = await tagTurnoverRepository.getUnmatched();

      setState(() {
        _pendingTurnovers = unmatched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending turnovers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePendingTurnover(TagTurnover tagTurnover) async {
    if (!mounted) return;

    try {
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();
      await tagTurnoverRepository.deleteTagTurnover(tagTurnover.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pending turnover deleted')),
        );
        _loadPendingTurnovers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting turnover: $e')));
      }
    }
  }

  Future<void> _editPendingTurnover(TagTurnover tagTurnover) async {
    if (!mounted) return;

    final result = await TagTurnoverEditorDialog.show(
      context,
      tagTurnover: tagTurnover,
    );

    if (!mounted || result == null) return;

    switch (result) {
      case EditTagTurnoverDeleted():
        await _deletePendingTurnover(tagTurnover);
      case EditTagTurnoverUpdated(:final tagTurnover):
        try {
          final tagTurnoverRepository = context.read<TagTurnoverRepository>();
          await tagTurnoverRepository.updateTagTurnover(tagTurnover);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pending turnover updated')),
            );
            _loadPendingTurnovers();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating turnover: $e')),
            );
          }
        }
    }
  }

  Future<void> _unmatchTurnover(TagTurnover tagTurnover) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmatch Turnover'),
        content: const Text(
          'This will unlink the turnover from the bank transaction. The turnover will become pending again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final matchingService = context.read<TurnoverMatchingService>();
      final success = await matchingService.unmatch(tagTurnover.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turnover unmatched successfully')),
          );
          _loadPendingTurnovers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unmatch turnover')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unmatching turnover: $e')),
        );
      }
    }
  }

  Future<void> _materializeTurnover(
    TagTurnover tagTurnover,
    Account account,
  ) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Materialize Turnover'),
        content: Text(
          'Create a bank turnover for this entry on account "${account.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final turnoverRepository = context.read<TurnoverRepository>();
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();

      // Create a new turnover
      final newTurnover = Turnover(
        id: const Uuid().v4obj(),
        accountId: account.id,
        amountValue: tagTurnover.amountValue,
        amountUnit: tagTurnover.amountUnit,
        bookingDate: tagTurnover.bookingDate,
        createdAt: DateTime.now(),
        purpose: tagTurnover.note ?? '',
      );

      await turnoverRepository.createTurnover(newTurnover);

      // Link the tag turnover to the new turnover
      await tagTurnoverRepository.allocateToTurnover(
        tagTurnover.id,
        newTurnover.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnover materialized successfully')),
        );
        _loadPendingTurnovers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error materializing turnover: $e')),
        );
      }
    }
  }

  Future<void> _findMatch(TagTurnover tagTurnover) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final matchingService = context.read<TurnoverMatchingService>();
      final matches = await matchingService.findMatchesForTagTurnover(
        tagTurnover,
      );
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show match dialog with all matches
      final selectedMatch = await showDialog<TagTurnoverMatch>(
        context: context,
        useSafeArea: false,
        builder: (context) =>
            _MatchSelectionDialog(matches: matches, tagTurnover: tagTurnover),
      );

      if (!mounted || selectedMatch == null) return;

      // Confirm the selected match
      await matchingService.confirmMatch(selectedMatch);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Match confirmed')));
        _loadPendingTurnovers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error finding match: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Turnovers')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(_errorMessage!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPendingTurnovers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _pendingTurnovers == null || _pendingTurnovers!.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending turnovers',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All turnovers have been matched',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) {
                  return RefreshIndicator(
                    onRefresh: _loadPendingTurnovers,
                    child: ListView.builder(
                      itemCount: _pendingTurnovers!.length,
                      itemBuilder: (context, index) {
                        final item = _pendingTurnovers![index];
                        final account = state.accountById[item.accountId];
                        return _PendingTurnoverItem(
                          tagTurnover: item,
                          onEdit: () => _editPendingTurnover(item),
                          onUnmatch: item.isMatched
                              ? () => _unmatchTurnover(item)
                              : null,
                          onMaterialize:
                              account != null &&
                                  account.syncSource == SyncSource.manual &&
                                  !item.isMatched
                              ? () => _materializeTurnover(item, account)
                              : null,
                          onFindMatch:
                              account != null &&
                                  account.syncSource != SyncSource.manual &&
                                  !item.isMatched
                              ? () => _findMatch(item)
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PendingTurnoverItem extends StatelessWidget {
  final TagTurnover tagTurnover;
  final VoidCallback? onEdit;
  final VoidCallback? onUnmatch;
  final VoidCallback? onMaterialize;
  final VoidCallback? onFindMatch;

  const _PendingTurnoverItem({
    required this.tagTurnover,
    this.onEdit,
    this.onUnmatch,
    this.onMaterialize,
    this.onFindMatch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = tagTurnover;
    final tagId = tagTurnover.tagId;
    final accountId = tagTurnover.accountId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  final tag = tagState.tagById[tagId];
                  return Row(
                    children: [
                      TagAvatar(tag: tag, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tt.note ?? tag?.name ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tag?.name ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        tt.format(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: tt.amountValue < Decimal.zero
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) {
                  final account = state.accountById[accountId];
                  return Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(tt.bookingDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        account?.syncSource?.icon ?? Icons.account_balance,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        account?.name ?? 'Unknown Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        tt.isMatched
                            ? Icons.check_circle_outline
                            : Icons.pending_outlined,
                        size: 12,
                        color: tt.isMatched
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tt.isMatched ? 'Matched' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: tt.isMatched
                              ? Colors.green
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (onMaterialize != null ||
                  onFindMatch != null ||
                  onUnmatch != null)
                const SizedBox(height: 8),
              if (onMaterialize != null ||
                  onFindMatch != null ||
                  onUnmatch != null)
                Row(
                  children: [
                    if (onMaterialize != null)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onMaterialize,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Materialize'),
                        ),
                      ),
                    if (onFindMatch != null)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onFindMatch,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Find Match'),
                        ),
                      ),
                    if (onUnmatch != null)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onUnmatch,
                          icon: const Icon(Icons.link_off, size: 18),
                          label: const Text('Unmatch'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchSelectionDialog extends StatefulWidget {
  final List<TagTurnoverMatch> matches;
  final TagTurnover tagTurnover;

  const _MatchSelectionDialog({
    required this.matches,
    required this.tagTurnover,
  });

  @override
  State<_MatchSelectionDialog> createState() => _MatchSelectionDialogState();
}

class _MatchSelectionDialogState extends State<_MatchSelectionDialog> {
  late TagTurnoverMatch? _selectedMatch;

  @override
  void initState() {
    super.initState();
    // Pre-select the best match (first one)
    _selectedMatch = widget.matches.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TagCubit, TagState>(
      builder: (context, tagState) {
        final tag = tagState.tagById[widget.tagTurnover.tagId];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              '${widget.matches.length} Match${widget.matches.length > 1 ? 'es' : ''} Found',
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              FilledButton(
                onPressed: _selectedMatch != null
                    ? () => Navigator.of(context).pop(_selectedMatch)
                    : null,
                child: const Text('Confirm Match'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (tag != null)
                  SourceCard(tagTurnover: widget.tagTurnover, tag: tag),
                Expanded(
                  child: RadioGroup<TagTurnoverMatch>(
                    groupValue: _selectedMatch,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMatch = value;
                        });
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.matches.length + 1,
                      itemBuilder: (context, index) {
                        if (index >= widget.matches.length) {
                          final minConf =
                              (TurnoverMatchingService.minConfidence * 100)
                                  .round();
                          return Column(
                            children: [
                              if (widget.matches.isEmpty) ...[
                                SizedBox(height: 32),
                                Icon(Icons.search_off, size: 48),
                                SizedBox(height: 16),
                                Text('No Matches Found'),
                                SizedBox(height: 32),
                              ],
                              Text(
                                '${widget.matches.isEmpty ? '' : 'Match not found? '}'
                                'This list only shows '
                                'transactions with a confidence of at least'
                                ' $minConf%. You can always navigate to a '
                                'transaction and there select from the pending '
                                'entries, no matter the matching score.',
                              ),
                            ],
                          );
                        }
                        final match = widget.matches[index];
                        final isSelected = match == _selectedMatch;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedMatch = match;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Radio<TagTurnoverMatch>(value: match),
                                          Text(
                                            '${(match.confidence * 100).toStringAsFixed(0)}% confidence',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? theme
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 20,
                                        ),
                                        tooltip: 'Open Turnover',
                                        onPressed: () {
                                          // Navigate to the turnover tags page
                                          context.push(
                                            TurnoverTagsRoute(
                                              turnoverId:
                                                  match.turnover.id.uuid,
                                            ).location,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _TurnoverMatchDetails(
                                    turnover: match.turnover,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TurnoverMatchDetails extends StatelessWidget {
  final Turnover turnover;

  const _TurnoverMatchDetails({required this.turnover});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                turnover.formatAmount(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: turnover.amountValue < Decimal.zero
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (turnover.bookingDate != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  turnover.formatDate() ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (turnover.purpose.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Purpose',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              turnover.purpose,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (turnover.counterPart != null &&
              turnover.counterPart!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Counter Party',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Flexible(
                  child: Text(
                    turnover.counterPart!,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
