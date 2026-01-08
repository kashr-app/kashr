import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/theme.dart';
import 'package:uuid/uuid.dart';

class OpeningBalanceCard extends StatelessWidget {
  final UuidValue accountId;

  const OpeningBalanceCard({required this.accountId, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final account = state.accountById[accountId];

        if (account == null) {
          return const SizedBox.shrink();
        }

        final currency = Currency.currencyFrom(account.currency);
        final balanceDate = account.openingBalanceDate;
        final balance = account.openingBalance;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () => _showOpeningBalanceDialog(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opening Balance',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          '${account.name} • ${context.dateFormat.format(balanceDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currency.format(balance),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).decimalColor(balance),
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOpeningBalanceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opening Balance'),
        content: const Text(
          'The opening balance is calculated as your current account balance '
          'minus the sum of all transactions on the account. The date states '
          'when it was last re-calculated, typically when the current balance '
          'is updated (e.g. during sync).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
