import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/comdirect/comdirect_api.dart';
import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_service.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LoadBankDataSection extends StatelessWidget {
  const LoadBankDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.move_to_inbox_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Download bank data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, dashboardState) {
                return BlocBuilder<ComdirectAuthCubit, ComdirectAuthState>(
                  builder: (context, authState) {
                    return TextButton(
                      onPressed: _buildOnLoadDataAction(
                        dashboardState.selectedPeriod,
                        context,
                        authState,
                      ),
                      child: dashboardState.bankDownloadStatus.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Load'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  VoidCallback? _buildOnLoadDataAction(
    YearMonth period,
    BuildContext context,
    ComdirectAuthState authState,
  ) {
    final isAuthed = authState is AuthSuccess;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final dashboardCubit = context.read<DashboardCubit>();
    ComdirectService instantiateService(ComdirectAPI api) => ComdirectService(
      comdirectAPI: api,
      accountCubit: context.read<AccountCubit>(),
      turnoverCubit: context.read<TurnoverCubit>(),
      matchingService: context.read<TurnoverMatchingService>(),
    );
    final cubit = context.read<ComdirectAuthCubit>();
    if (isAuthed) {
      return () => dashboardCubit.downloadBankData(
        instantiateService(authState.api),
        messenger,
      );
    } else {
      return () async {
        messenger.showSnackBar(
          SnackBar(content: Text('Please login at the bank to download data.')),
        );
        await router.push(ComdirectLoginRoute().location);
        final s = cubit.state;
        if (s is AuthSuccess) {
          dashboardCubit.downloadBankData(instantiateService(s.api), messenger);
        }
      };
    }
  }
}
