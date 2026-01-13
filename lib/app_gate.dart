import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/account_all_turnovers_page.dart';
import 'package:kashr/account/account_details_page.dart';
import 'package:kashr/account/accounts_page.dart';
import 'package:kashr/account/create_account_page.dart';
import 'package:kashr/account/edit_account_page.dart';
import 'package:kashr/analytics/analytics_page.dart';
import 'package:kashr/backup/backup_list_page.dart';
import 'package:kashr/comdirect/comdirect_login_page.dart';
import 'package:kashr/dashboard/dashboard_page.dart';
import 'package:kashr/splash_page.dart';
import 'package:kashr/local_auth/cubit/local_auth_cubit.dart';
import 'package:kashr/local_auth/local_auth_login_page.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/onboarding/onboarding_page.dart';
import 'package:kashr/savings/savings_detail_page.dart';
import 'package:kashr/savings/savings_overview_page.dart';
import 'package:kashr/logging/log_viewer_page.dart';
import 'package:kashr/settings/amazon_order_detection_page.dart';
import 'package:kashr/settings/banks_page.dart';
import 'package:kashr/settings/help_page.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/settings/settings_page.dart';
import 'package:kashr/settings/settings_state.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/transfers_filter.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/tag_turnovers_page.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:kashr/turnover/tags_page.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
import 'package:kashr/turnover/pending_turnovers_page.dart';
import 'package:kashr/turnover/transfer_editor_page.dart';
import 'package:kashr/turnover/transfers_page.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part '_gen/app_gate.g.dart';

@TypedShellRoute<AppGateShellRoute>(
  routes: <TypedGoRoute<GoRouteData>>[
    TypedGoRoute<OnboardingRoute>(path: '/onboarding'),
    TypedGoRoute<LocalAuthLoginRoute>(path: '/auth'),
    TypedGoRoute<DashboardRoute>(
      path: '/dashboard',
      routes: [
        TypedGoRoute<SettingsRoute>(
          path: 'settings',
          routes: [
            TypedGoRoute<BanksRoute>(
              path: 'banks',
              routes: [TypedGoRoute<ComdirectLoginRoute>(path: 'comdirect')],
            ),
            TypedGoRoute<BackupListRoute>(
              path: 'backups',
              routes: [
                TypedGoRoute<NextcloudSettingsRoute>(
                  path: 'nextcloud-settings',
                ),
              ],
            ),
            TypedGoRoute<TagsRoute>(path: 'tags'),
            TypedGoRoute<TagTurnoversRoute>(path: 'tagturnovers'),
            TypedGoRoute<LogViewerRoute>(path: 'logs'),
            TypedGoRoute<AmazonOrderDetectionRoute>(
              path: 'amazon-order-detection',
            ),
            TypedGoRoute<HelpRoute>(path: 'help'),
          ],
        ),
        TypedGoRoute<TurnoversRoute>(
          path: 'turnovers',
          routes: [TypedGoRoute<TurnoverTagsRoute>(path: ':turnoverId/tags')],
        ),
        TypedGoRoute<PendingTurnoversRoute>(path: 'pending-turnovers'),
        TypedGoRoute<TransfersRoute>(
          path: 'transfers',
          routes: [TypedGoRoute<TransferEditorRoute>(path: ':transferId/edit')],
        ),
        TypedGoRoute<AccountsRoute>(
          path: 'accounts',
          routes: [
            TypedGoRoute<CreateAccountRoute>(path: 'create'),
            TypedGoRoute<AccountDetailsRoute>(
              path: ':accountId',
              routes: [
                TypedGoRoute<EditAccountRoute>(path: 'edit'),
                TypedGoRoute<AccountAllTurnoversRoute>(path: 'turnovers'),
              ],
            ),
          ],
        ),
        TypedGoRoute<SavingsRoute>(
          path: 'savings',
          routes: [TypedGoRoute<SavingsDetailRoute>(path: ':savingsId')],
        ),
        TypedGoRoute<AnalyticsRoute>(path: 'analytics'),
      ],
    ),
  ],
)
class AppGateShellRoute extends ShellRouteData {
  const AppGateShellRoute();

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) {
    return AppGate(currentLocation: state.matchedLocation, child: navigator);
  }
}

/// A shell widget that wraps all protected routes and enforces authentication.
///
/// If the user is not authenticated or hasn't completed onboarding, this widget
/// will redirect them appropriately WITHOUT rendering the child routes.
/// This prevents data exposure from deep links.
class AppGate extends StatefulWidget {
  final String currentLocation;
  final Widget child;

  const AppGate({
    required this.currentLocation,
    required this.child,
    super.key,
  });

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  @override
  void initState() {
    super.initState();
    // Check auth immediately when shell is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAuthAndRedirect(context);
      }
    });
  }

  void _checkAuthAndRedirect(BuildContext context) async {
    final log = context.read<LogService>().log;

    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri
        .toString();

    // Onboarding always wins, even before authentication
    final settingsCubit = context.read<SettingsCubit>();
    final settingsState = settingsCubit.initialized
        ? settingsCubit.state
        : await settingsCubit.load();
    if (!context.mounted) {
      return;
    }
    final onboardingRoute = const OnboardingRoute();
    if (settingsState.onboardingCompletedOn == null) {
      if (currentLocation != onboardingRoute.location) {
        log.d('Redirecting to onboarding');
        onboardingRoute.go(context);
      }
      return;
    }

    // check authentication

    final localAuthCubit = context.read<LocalAuthCubit>();
    final authState = localAuthCubit.state;

    switch (authState) {
      case LocalAuthLoading():
        log.d('Auth loading, waiting...');
        return;
      case LocalAuthSuccess():
        final authLocation = LocalAuthLoginRoute().location;
        final savedLocation = localAuthCubit.popSavedLocation();
        if (savedLocation != null && savedLocation != authLocation) {
          log.d('Authenticated, restoring saved location: $savedLocation');
          return router.go(savedLocation);
        }
        log.d('Authenticated, no saved location');
        final dashboardLocation = const DashboardRoute().location;
        if (currentLocation == dashboardLocation) {
          return;
        }
        if ([
          authLocation,
          onboardingRoute.location,
        ].contains(currentLocation)) {
          log.d('Redirecting to dashboard');
          return router.go(dashboardLocation);
        }
        log.d('Not redirecting because the user is already on an authed page');
        return;
      case LocalAuthInitial():
        log.d('Auth inital');
        continue redirectToAuth;
      case LocalAuthLoggedOut():
        log.d('Logged out');
        continue redirectToAuth;
      redirectToAuth:
      case LocalAuthError():
        log.d('Not authenticated');
        final authLocation = const LocalAuthLoginRoute().location;
        if (currentLocation != authLocation) {
          log.d('Saving non-auth location: $currentLocation');
          localAuthCubit.saveLocationForLater(currentLocation);
        }
        if (currentLocation == authLocation) {
          return;
        }
        log.d('Redirecting to login');
        return router.go(authLocation);
    }
  }

  final _publicRoutes = [LocalAuthLoginRoute(), OnboardingRoute()];
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select(
      (LocalAuthCubit c) => c.state is LocalAuthSuccess,
    );

    final isPublicRoute = _publicRoutes.any(
      (it) => it.location == widget.currentLocation,
    );
    final isAuthorized = isPublicRoute || isAuthenticated;

    return MultiBlocListener(
      listeners: [
        BlocListener<LocalAuthCubit, LocalAuthState>(
          listenWhen: (previous, current) => previous != current,
          listener: (context, _) {
            _checkAuthAndRedirect(context);
          },
        ),
        BlocListener<SettingsCubit, SettingsState>(
          listenWhen: (previous, current) =>
              previous.onboardingCompletedOn != current.onboardingCompletedOn,
          listener: (context, _) => _checkAuthAndRedirect(context),
        ),
      ],
      child: isAuthorized ? widget.child : const SplashPage(),
    );
  }
}
