import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:finanalyzer/home_page.dart' as home;
import 'package:finanalyzer/main.dart';
import 'package:finanalyzer/local_auth/local_auth_login_page.dart'
    as local_auth;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

final log = Logger();

final GoRouter router = GoRouter(
  initialLocation: const local_auth.LocalAuthLoginRoute().location,
  routes: [...local_auth.$appRoutes, ...home.$appRoutes],
  redirect: (BuildContext context, GoRouterState state) {
    final isAuthenticated =
        isDevelopment ||
        context.read<LocalAuthCubit>().state is LocalAuthSuccess;

    final bool loggingIn =
        state.matchedLocation ==
        const local_auth.LocalAuthLoginRoute().location;

    if (!isAuthenticated && !loggingIn) {
      log.i('Redirecting to login');
      return const local_auth.LocalAuthLoginRoute().location;
    }
    if (isAuthenticated && loggingIn) {
      return const home.HomeRoute().location;
    }
    return null;
  },
);
