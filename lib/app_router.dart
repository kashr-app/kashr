import 'package:kashr/dashboard/dashboard_page.dart';
import 'package:kashr/app_gate.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  late final GoRouter router;

  AppRouter() {
    router = GoRouter(
      initialLocation: const DashboardRoute().location,
      routes: $appRoutes,
    );
  }
}
