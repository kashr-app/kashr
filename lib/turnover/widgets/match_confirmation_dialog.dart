import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MatchConfirmationDialog extends StatefulWidget {
  final List<MatchSuggestion> suggestions;

  const MatchConfirmationDialog({required this.suggestions, super.key});

  @override
  State<MatchConfirmationDialog> createState() =>
      _MatchConfirmationDialogState();
}

class _MatchConfirmationDialogState extends State<MatchConfirmationDialog> {
  int _currentIndex = 0;
  bool _isProcessing = false;

  Future<void> _confirmMatch() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final suggestion = widget.suggestions[_currentIndex];
      final matchingService = context.read<TurnoverMatchingService>();

      await matchingService.confirmMatch(suggestion.match);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match confirmed')),
        );

        _moveToNext();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming match: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _skipMatch() {
    _moveToNext();
  }

  void _moveToNext() {
    if (_currentIndex < widget.suggestions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // All matches reviewed
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestion = widget.suggestions[_currentIndex];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Suggested Match',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '${_currentIndex + 1}/${widget.suggestions.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTurnoverCard(
              context,
              suggestion.turnover,
              theme,
              title: 'Bank Transaction',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.compare_arrows,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(suggestion.match.confidence * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTagTurnoverCard(
              context,
              suggestion.tagTurnover,
              theme,
              title: 'Your Entry',
            ),
            if (suggestion.turnover.amountValue !=
                suggestion.tagTurnover.amountValue) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.warningContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onWarningContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount will be adjusted to match bank transaction',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onWarningContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _skipMatch,
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmMatch,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm Match'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoverCard(
    BuildContext context,
    Turnover turnover,
    ThemeData theme, {
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            turnover.purpose,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                turnover.formatDate() ?? 'No date',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                turnover.formatAmount(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: turnover.amountValue.toDouble() < 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagTurnoverCard(
    BuildContext context,
    TagTurnover tagTurnover,
    ThemeData theme, {
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagTurnover.note ?? 'Logged expense',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tagTurnover.bookingDate.day.toString().padLeft(2, '0')}.${tagTurnover.bookingDate.month.toString().padLeft(2, '0')}.${tagTurnover.bookingDate.year}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                tagTurnover.format(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tagTurnover.amountValue.toDouble() < 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Represents a match suggestion to show to the user
class MatchSuggestion {
  final Turnover turnover;
  final TagTurnover tagTurnover;
  final TagTurnoverMatch match;

  MatchSuggestion({
    required this.turnover,
    required this.tagTurnover,
    required this.match,
  });
}

// Extension to add warningContainer color scheme support
extension on ColorScheme {
  Color get warningContainer => tertiary.withValues(alpha: 0.1);
  Color get onWarningContainer => onTertiary;
}
