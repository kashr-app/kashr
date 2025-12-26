import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/widgets/dashboard_hint.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:kashr/turnover/turnovers_page.dart';

class UnallocatedHint extends StatelessWidget {
  const UnallocatedHint({
    super.key,
    required this.unallocatedCountTotal,
    required this.unallocatedSumTotal,
  });

  final int unallocatedCountTotal;
  final Decimal unallocatedSumTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardHint(
      icon: Icon(Icons.label),
      title:
          '$unallocatedCountTotal need tagging (${Currency.currencyFrom('EUR').formatCompact(unallocatedSumTotal)})',
      color: theme.colorScheme.onSecondaryContainer,
      colorBackground: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.5,
      ),
      onTap: () => TurnoversRoute(
        filter: TurnoverFilter(unallocatedOnly: true),
        sort: const TurnoverSort(
          orderBy: SortField.amount,
          direction: SortDirection.desc,
        ),
      ).go(context),
    );
  }
}
