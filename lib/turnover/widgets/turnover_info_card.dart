import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
            BlocBuilder<AccountCubit, AccountState>(
              builder: (context, state) => Row(
                children: [
                  Icon(
                    state.accountById[turnover.accountId]?.accountType.icon,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(state.accountById[turnover.accountId]?.name ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              turnover.counterPart ?? '(Unknown)',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(turnover.purpose, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  turnover.formatDate() ?? '',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  turnover.formatAmount(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).decimalColor(turnover.amountValue),
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
