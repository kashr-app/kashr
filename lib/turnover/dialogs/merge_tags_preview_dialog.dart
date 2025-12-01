import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';

/// Result of the merge preview dialog.
class MergePreviewResult {
  final bool proceed;

  const MergePreviewResult({required this.proceed});
}

/// A dialog that shows merge preview with savings implications.
///
/// Displays what will happen during the merge, especially regarding savings.
/// If both tags have savings, user must choose which to keep.
class MergeTagsPreviewDialog extends StatefulWidget {
  final Tag sourceTag;
  final Tag targetTag;
  final Savings? sourceSavings;
  final Savings? targetSavings;
  final Decimal? sourceBalance;
  final Decimal? targetBalance;

  const MergeTagsPreviewDialog({
    super.key,
    required this.sourceTag,
    required this.targetTag,
    this.sourceSavings,
    this.targetSavings,
    this.sourceBalance,
    this.targetBalance,
  });

  static Future<MergePreviewResult?> show(
    BuildContext context, {
    required Tag sourceTag,
    required Tag targetTag,
    Savings? sourceSavings,
    Savings? targetSavings,
    Decimal? sourceBalance,
    Decimal? targetBalance,
  }) {
    return showDialog<MergePreviewResult>(
      context: context,
      builder: (context) => MergeTagsPreviewDialog(
        sourceTag: sourceTag,
        targetTag: targetTag,
        sourceSavings: sourceSavings,
        targetSavings: targetSavings,
        sourceBalance: sourceBalance,
        targetBalance: targetBalance,
      ),
    );
  }

  @override
  State<MergeTagsPreviewDialog> createState() => _MergeTagsPreviewDialogState();
}

class _MergeTagsPreviewDialogState extends State<MergeTagsPreviewDialog> {
  @override
  void initState() {
    super.initState();
  }

  bool get _hasSavingsConflict =>
      widget.sourceSavings != null && widget.targetSavings != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Merge Tags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TagPreviewRow(label: 'From', tag: widget.sourceTag),
            const SizedBox(height: 8),
            Center(
              child: Icon(
                Icons.arrow_downward,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _TagPreviewRow(label: 'Into', tag: widget.targetTag),
            const SizedBox(height: 24),
            Text(
              'All transactions from "${widget.sourceTag.name}" will be moved to "${widget.targetTag.name}".',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _buildSavingsImplications(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const MergePreviewResult(proceed: false)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(MergePreviewResult(proceed: true)),
          child: const Text('Proceed'),
        ),
      ],
    );
  }

  Widget _buildSavingsImplications(ThemeData theme) {
    final hasSourceSavings = widget.sourceSavings != null;
    final hasTargetSavings = widget.targetSavings != null;

    if (!hasSourceSavings && !hasTargetSavings) {
      return _InfoCard(
        icon: Icons.info_outline,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Text('No savings associated with either tag.'),
      );
    }

    if (_hasSavingsConflict) {
      return _buildConflictSection(theme);
    }

    if (hasSourceSavings) {
      return _buildSourceOnlySavings(theme);
    }

    return _buildTargetOnlySavings(theme);
  }

  Widget _buildSourceOnlySavings(ThemeData theme) {
    final balance = widget.sourceBalance ?? Decimal.zero;
    final formatted = Currency.EUR.format(balance);

    return _InfoCard(
      icon: Icons.savings_outlined,
      color: theme.colorScheme.primaryContainer,
      child: Text(
        'Source savings ($formatted) will be transferred to "${widget.targetTag.name}".',
      ),
    );
  }

  Widget _buildTargetOnlySavings(ThemeData theme) {
    final balance = widget.targetBalance ?? Decimal.zero;
    final formatted = Currency.EUR.format(balance);

    return _InfoCard(
      icon: Icons.info_outline,
      color: theme.colorScheme.primaryContainer,
      child: Text(
        '"${widget.targetTag.name}" has savings ($formatted). After merge, "${widget.sourceTag.name}" transactions will also count toward this savings.',
      ),
    );
  }

  Widget _buildConflictSection(ThemeData theme) {
    return _InfoCard(
      icon: Icons.warning_amber_rounded,
      color: theme.colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both tags have savings. Savings from the source will be merged into the target savings.',
            style: TextStyle(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPreviewRow extends StatelessWidget {
  final String label;
  final Tag tag;

  const _TagPreviewRow({required this.label, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TagAvatar(tag: tag, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag.name, style: theme.textTheme.titleMedium),
              if (tag.isTransfer)
                Text(
                  'Transfer',
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget child;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
