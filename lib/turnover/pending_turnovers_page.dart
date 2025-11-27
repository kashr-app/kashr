import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  List<TagTurnoverWithTagAndAccount>? _pendingTurnovers;
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
      final tagRepository = context.read<TagRepository>();
      final accountRepository = context.read<AccountRepository>();

      final unmatched = await tagTurnoverRepository.getUnmatched();
      final allTags = await tagRepository.getAllTags();
      final tagMap = {for (final tag in allTags) tag.id!: tag};

      final allAccounts = await accountRepository.findAll();
      final accountMap = {for (final acc in allAccounts) acc.id!: acc};

      final withTagsAndAccounts = unmatched.map((tt) {
        final tag = tagMap[tt.tagId];
        final account = accountMap[tt.accountId];
        return TagTurnoverWithTagAndAccount(
          tagTurnover: tt,
          tag: tag ?? Tag(name: 'Unknown', id: tt.tagId),
          account: account,
        );
      }).toList();

      setState(() {
        _pendingTurnovers = withTagsAndAccounts;
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Turnover'),
        content: const Text(
          'Are you sure you want to delete this pending turnover?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();
      await tagTurnoverRepository.deleteTagTurnover(tagTurnover.id!);

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
      final success = await matchingService.unmatch(tagTurnover.id!);

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
        accountId: account.id!,
        amountValue: tagTurnover.amountValue,
        amountUnit: tagTurnover.amountUnit,
        bookingDate: tagTurnover.bookingDate,
        createdAt: DateTime.now(),
        purpose: tagTurnover.note ?? '',
      );

      await turnoverRepository.createTurnover(newTurnover);

      // Link the tag turnover to the new turnover
      await tagTurnoverRepository.linkToTurnover(
        tagTurnover.id!,
        newTurnover.id!,
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

  Future<void> _findMatch(TagTurnover tagTurnover, Account account) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final turnoverRepository = context.read<TurnoverRepository>();
      final matchingService = context.read<TurnoverMatchingService>();

      // Get all turnovers for this account
      final turnovers = await turnoverRepository.getTurnoversForAccount(
        accountId: account.id!,
      );

      // Find best match for each turnover
      Turnover? bestMatchTurnover;
      double bestConfidence = 0.0;

      for (final turnover in turnovers) {
        // Skip if turnover has no ID
        if (turnover.id == null) continue;

        // Create a temporary synced turnover to find matches
        final matches = await matchingService.findMatches(turnover);

        for (final match in matches) {
          if (match.tagTurnoverId == tagTurnover.id &&
              match.confidence > bestConfidence) {
            bestMatchTurnover = turnover;
            bestConfidence = match.confidence;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (bestMatchTurnover != null) {
        // Show match found dialog with option to confirm or open
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Match Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found a match with ${(bestConfidence * 100).toStringAsFixed(0)}% confidence:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                _TurnoverMatchDetails(turnover: bestMatchTurnover!),
                const SizedBox(height: 16),
                const Text(
                  'Would you like to confirm this match?',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('open'),
                child: const Text('Open Turnover'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('confirm'),
                child: const Text('Confirm Match'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (action == 'confirm') {
          // Confirm the match
          await matchingService.confirmMatch(
            TagTurnoverMatch(
              tagTurnoverId: tagTurnover.id!,
              turnoverId: bestMatchTurnover.id!,
              confidence: bestConfidence,
            ),
          );

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Match confirmed')));
            _loadPendingTurnovers();
          }
        } else if (action == 'open') {
          // Navigate to the turnover tags page
          if (mounted) {
            context.push(
              TurnoverTagsRoute(
                turnoverId: bestMatchTurnover.id!.uuid,
              ).location,
            );
            _loadPendingTurnovers();
          }
        }
      } else {
        // No match found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No match found'),
            duration: Duration(seconds: 2),
          ),
        );
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
            : RefreshIndicator(
                onRefresh: _loadPendingTurnovers,
                child: ListView.builder(
                  itemCount: _pendingTurnovers!.length,
                  itemBuilder: (context, index) {
                    final item = _pendingTurnovers![index];
                    return _PendingTurnoverItem(
                      tagTurnoverWithTagAndAccount: item,
                      onDelete: () => _deletePendingTurnover(item.tagTurnover),
                      onUnmatch: item.tagTurnover.isMatched
                          ? () => _unmatchTurnover(item.tagTurnover)
                          : null,
                      onMaterialize:
                          item.account != null &&
                              item.account!.syncSource == SyncSource.manual &&
                              !item.tagTurnover.isMatched
                          ? () => _materializeTurnover(
                              item.tagTurnover,
                              item.account!,
                            )
                          : null,
                      onFindMatch:
                          item.account != null &&
                              item.account!.syncSource != SyncSource.manual &&
                              !item.tagTurnover.isMatched
                          ? () => _findMatch(item.tagTurnover, item.account!)
                          : null,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _PendingTurnoverItem extends StatelessWidget {
  final TagTurnoverWithTagAndAccount tagTurnoverWithTagAndAccount;
  final VoidCallback onDelete;
  final VoidCallback? onUnmatch;
  final VoidCallback? onMaterialize;
  final VoidCallback? onFindMatch;

  const _PendingTurnoverItem({
    required this.tagTurnoverWithTagAndAccount,
    required this.onDelete,
    this.onUnmatch,
    this.onMaterialize,
    this.onFindMatch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = tagTurnoverWithTagAndAccount.tagTurnover;
    final tag = tagTurnoverWithTagAndAccount.tag;
    final account = tagTurnoverWithTagAndAccount.account;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagAvatar(tag: tag, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tt.note ?? tag.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tag.name,
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
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${tt.bookingDate.day.toString().padLeft(2, '0')}.${tt.bookingDate.month.toString().padLeft(2, '0')}.${tt.bookingDate.year}',
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
                  if (onMaterialize == null &&
                      onFindMatch == null &&
                      onUnmatch == null)
                    const Spacer(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: theme.colorScheme.error,
                    tooltip: 'Delete',
                  ),
                ],
              ),
          ],
        ),
      ),
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

class TagTurnoverWithTagAndAccount {
  final TagTurnover tagTurnover;
  final Tag tag;
  final Account? account;

  TagTurnoverWithTagAndAccount({
    required this.tagTurnover,
    required this.tag,
    this.account,
  });
}
