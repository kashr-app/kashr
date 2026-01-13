import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:kashr/account/accounts_page.dart';
import 'package:kashr/analytics/analytics_page.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/core/widgets/period_selector.dart';
import 'package:kashr/account/account_selector_dialog.dart';
import 'package:kashr/account/dual_account_selector.dart';
import 'package:kashr/app_gate.dart';
import 'package:kashr/dashboard/widgets/unallocated_hint.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/savings/savings_overview_page.dart';
import 'package:kashr/dashboard/cubit/dashboard_cubit.dart';
import 'package:kashr/dashboard/cubit/dashboard_state.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/dashboard/widgets/cashflow_card.dart';
import 'package:kashr/dashboard/widgets/income_summary_card.dart';
import 'package:kashr/dashboard/widgets/load_bank_data_section.dart';
import 'package:kashr/dashboard/widgets/pending_turnovers_hint.dart';
import 'package:kashr/dashboard/widgets/transfers_need_review_hint.dart';
import 'package:kashr/dashboard/widgets/spending_summary_card.dart';
import 'package:kashr/dashboard/widgets/transfer_summary_card.dart';
import 'package:kashr/dashboard/widgets/unallocated_turnovers_section.dart';
import 'package:kashr/settings/settings_page.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:kashr/turnover/widgets/quick_transfer_entry_sheet.dart';
import 'package:kashr/turnover/widgets/quick_turnover_entry_sheet.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardRoute extends GoRouteData with $DashboardRoute {
  const DashboardRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const DashboardPage();
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        context.read<TurnoverRepository>(),
        context.read<TurnoverService>(),
        context.read<TagTurnoverRepository>(),
        context.read<TagRepository>(),
        context.read<TransferRepository>(),
        context.read<LogService>().log,
      )..loadPeriodData(),
      child: const _DashboardPage(),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => const AccountsRoute().go(context),
            icon: const Icon(iconAccounts),
            tooltip: 'Accounts',
          ),
          IconButton(
            onPressed: () => const TurnoversRoute().go(context),
            icon: const Icon(iconTurnover),
            tooltip: 'Turnovers',
          ),
          IconButton(
            onPressed: () => const SavingsRoute().go(context),
            icon: const Icon(iconSavings),
            tooltip: 'Savings',
          ),
          IconButton(
            onPressed: () => const AnalyticsRoute().go(context),
            icon: const Icon(iconAnalytics),
            tooltip: 'Analytics',
          ),
          IconButton(
            onPressed: () => const SettingsRoute().go(context),
            icon: const Icon(iconSettings),
            tooltip: 'Settings',
          ),
        ],
        title: const Text('Kashr'),
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            if (state.status.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status.isError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'An error occurred',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<DashboardCubit>().loadPeriodData(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 0) {
                  context.read<DashboardCubit>().selectPeriod(
                    state.period.add(delta: -1),
                  );
                } else if (velocity < 0) {
                  context.read<DashboardCubit>().selectPeriod(
                    state.period.add(delta: 1),
                  );
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(
                  16,
                ).copyWith(bottom: 80), // let fab not hide the bottom
                children: [
                  if (state.pendingCount > 0) ...[
                    PendingTurnoversHint(
                      count: state.pendingCount,
                      totalAmount: state.pendingTotalAmount,
                    ),
                  ],
                  if (state.unallocatedCountTotal > 0) ...[
                    const SizedBox(height: 4),
                    UnallocatedHint(
                      unallocatedCountTotal: state.unallocatedCountTotal,
                      unallocatedSumTotal: state.unallocatedSumTotal,
                    ),
                  ],
                  if (state.transfersNeedingReviewCount > 0) ...[
                    const SizedBox(height: 4),
                    TransfersNeedReviewHint(
                      count: state.transfersNeedingReviewCount,
                    ),
                  ],
                  const SizedBox(height: 8),
                  PeriodSelector(
                    selectedPeriod: state.period,
                    onPeriodSelected: (period) =>
                        context.read<DashboardCubit>().selectPeriod(period),
                  ),
                  const SizedBox(height: 8),
                  const LoadBankDataSection(),
                  const SizedBox(height: 8),
                  CashflowCard(
                    period: state.period,
                    totalIncome: state.totalIncome,
                    totalExpenses: state.totalExpenses,
                    tagTurnoverCount: state.tagTurnoverCount,
                  ),
                  const SizedBox(height: 16),
                  UnallocatedTurnoversSection(
                    firstUnallocatedTurnover: state.firstUnallocatedTurnover,
                    unallocatedCountInPeriod: state.unallocatedCountInPeriod,
                    onRefresh: () =>
                        context.read<DashboardCubit>().loadPeriodData(),
                    period: state.period,
                  ),
                  const SizedBox(height: 16),
                  IncomeSummaryCard(
                    totalIncome: state.totalIncome,
                    unallocatedIncome: state.unallocatedIncome,
                    tagSummaries: state.incomeTagSummaries,
                    period: state.period,
                    predictionByTagId:
                        state.predictionByTagId[TurnoverSign.income] ?? {},
                  ),
                  const SizedBox(height: 16),
                  SpendingSummaryCard(
                    totalExpenses: -state.totalExpenses,
                    unallocatedExpenses: -state.unallocatedExpenses,
                    tagSummaries: state.expenseTagSummaries,
                    period: state.period,
                    predictionByTagId:
                        state.predictionByTagId[TurnoverSign.expense] ?? {},
                  ),
                  const SizedBox(height: 16),
                  TransferSummaryCard(
                    totalTransfers: state.totalTransfers,
                    tagSummaries: state.transferTagSummaries,
                    period: state.period,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FloatingActionButton(
              heroTag: null,
              onPressed: () => _showTransferDialog(context),
              tooltip: 'Log Transfer',
              child: const Icon(Icons.swap_horiz),
            ),
            Spacer(),
            FloatingActionButton(
              onPressed: () => _showQuickExpenseEntry(context),
              tooltip: 'Log Transaction',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickExpenseEntry(BuildContext context) async {
    final accountCubit = context.read<AccountCubit>();
    if (accountCubit.state.status.isLoading) {
      Status.error.snack(
        context,
        'Accounts still loading, please try again in a second.',
      );
      return;
    }
    final accounts = accountCubit.state.accountById;
    if (accounts.isEmpty) {
      Status.error.snack(context, 'Please create an account first');
      return;
    }

    // If only one account, use it directly
    if (accounts.length == 1) {
      await _showEntrySheetAndRefresh(context, accounts.values.first);
      return;
    }

    // Show account selector
    final selectedAccount = await AccountSelectorDialog.show(context);

    if (selectedAccount != null && context.mounted) {
      await _showEntrySheetAndRefresh(context, selectedAccount);
    }
  }

  /// Shows the QuickTurnoverEntrySheet and refreshes the dashboard if a
  /// turnover was successfully saved.
  Future<void> _showEntrySheetAndRefresh(
    BuildContext context,
    Account account,
  ) async {
    final result = await showModalBottomSheet<TagTurnover>(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuickTurnoverEntrySheet(account: account),
    );

    // Refresh dashboard if turnover was saved
    if (result != null && context.mounted) {
      unawaited(context.read<DashboardCubit>().loadPeriodData());
    }
  }

  void _showTransferDialog(BuildContext context) async {
    final accountCubit = context.read<AccountCubit>();
    if (accountCubit.state.status.isLoading) {
      Status.error.snack(
        context,
        'Accounts still loading, please try again in a second.',
      );
      return;
    }
    final accounts = accountCubit.state.accountById;
    if (accounts.length < 2) {
      Status.error.snack(context, 'Please create at least two accounts');
      return;
    }

    // Show account selector
    final result = await showDialog<TransferAccountSelection>(
      context: context,
      builder: (context) => DualAccountSelectorDialog(),
    );

    if (result != null && context.mounted) {
      final fromAccount = result.from;
      final toAccount = result.to;
      final wasAdded = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => QuickTransferEntrySheet(
          fromAccount: fromAccount,
          toAccount: toAccount,
        ),
      );

      // Refresh dashboard if turnover was saved
      if (wasAdded == true && context.mounted) {
        unawaited(context.read<DashboardCubit>().loadPeriodData());
      }
    }
  }
}
