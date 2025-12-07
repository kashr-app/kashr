import 'dart:async';

import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/comdirect/comdirect_api.dart';
import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_model.dart';
import 'package:finanalyzer/comdirect/comdirect_service.dart';
import 'package:finanalyzer/ingest/ingest.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                      onPressed: () async {
                        if (authState is AuthSuccess) {
                          await _downloadBankData(context, authState.api);
                        } else {
                          await _handleUnauthenticatedDownload(context);
                        }
                      },
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

  Future<void> _downloadBankData(BuildContext context, ComdirectAPI api) async {
    final service = _createComdirectService(context, api);
    final result = await context.read<DashboardCubit>().ingestData(service);
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      switch (result.status) {
        case ResultStatus.success:
          final autoMatchMsg = result.autoMatchedCount > 0
              ? ' ${result.autoMatchedCount} expenses auto-matched.'
              : '';
          final unmatchedMsg = result.unmatchedTurnovers.isNotEmpty
              ? ' ${result.unmatchedTurnovers.length} transactions need review.'
              : '';
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Data loaded successfully.$autoMatchMsg$unmatchedMsg',
              ),
            ),
          );
        case ResultStatus.unauthed:
          await _handleUnauthenticatedDownload(context);
        case ResultStatus.otherError:
          messenger.showSnackBar(
            SnackBar(
              content: Text('There was an error: ${result.errorMessage}'),
            ),
          );
      }
    }
  }

  ComdirectService _createComdirectService(
    BuildContext context,
    ComdirectAPI api,
  ) {
    return ComdirectService(
      comdirectAPI: api,
      accountCubit: context.read<AccountCubit>(),
      turnoverCubit: context.read<TurnoverCubit>(),
      matchingService: context.read<TurnoverMatchingService>(),
    );
  }

  Future<void> _handleUnauthenticatedDownload(BuildContext context) async {
    final credentials = await Credentials.load();
    if (!context.mounted) return;

    if (credentials == null) {
      _showLoginError(context, 'Please login to download data');
      return;
    }

    final authCubit = context.read<ComdirectAuthCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final subscription = authCubit.stream.listen((state) {
      if (state is WaitingForTANConfirmation) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please confirm the login in the your banking app'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    try {
      await authCubit.login(credentials);
      if (!context.mounted) {
        return;
      }

      final authState = authCubit.state;
      if (authState is AuthSuccess) {
        await _downloadBankData(context, authState.api);
      } else if (authState is AuthError) {
        _showLoginError(context, 'Login failed: ${authState.message}');
      }
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _navigateToLoginAndDownload(BuildContext context) async {
    await ComdirectLoginRoute().push(context);
    if (!context.mounted) return;

    final authState = context.read<ComdirectAuthCubit>().state;
    if (authState is AuthSuccess) {
      await _downloadBankData(context, authState.api);
    }
  }

  void _showLoginError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Login',
          onPressed: () async => await _navigateToLoginAndDownload(context),
        ),
      ),
    );
  }
}
