import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/pending_turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PendingTurnoversHint extends StatelessWidget {
  const PendingTurnoversHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagTurnoverRepository = context.read<TagTurnoverRepository>();

    return FutureBuilder<List<TagTurnover>>(
      future: tagTurnoverRepository.getUnmatched(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingTurnovers = snapshot.data!;
        final count = pendingTurnovers.length;
        final totalAmount = pendingTurnovers
            .map((tt) => tt.amountValue)
            .fold(Decimal.zero, (sum, amount) => sum + amount);

        // Assume EUR for now - we could get currency from account
        final currency = Currency.currencyFrom('EUR');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => const PendingTurnoversRoute().go(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_outlined,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$count pending ${count == 1 ? 'turnover' : 'turnovers'} '
                        '(${currency.format(totalAmount)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
