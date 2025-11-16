import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:flutter/material.dart';

/// Displays information about a turnover in a card format.
///
/// Shows the counter party, purpose, date, and formatted amount.
class TurnoverInfoCard extends StatelessWidget {
  final Turnover turnover;

  const TurnoverInfoCard({required this.turnover, super.key});

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
