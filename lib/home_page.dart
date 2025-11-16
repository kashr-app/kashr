import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_page.dart';
import 'package:finanalyzer/comdirect/turnover_screen.dart';
import 'package:finanalyzer/settings/settings_page.dart';
import 'package:finanalyzer/turnover_tag_page.dart';
import 'package:finanalyzer/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part '_gen/home_page.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/app',
  routes: <TypedGoRoute<GoRouteData>>[
    TypedGoRoute<SettingsRoute>(path: 'settings'),
    TypedGoRoute<TurnoversRoute>(
      path: 'turnovers',
      routes: [TypedGoRoute<TurnoverTagRoute>(path: ':turnoverId/tags')],
    ),
    TypedGoRoute<ComdirectRoute>(
      path: 'comdirect',
      routes: [
        TypedGoRoute<ComdirectLoginRoute>(path: 'login'),
        TypedGoRoute<ComdirectSyncRoute>(path: 'sync'),
      ],
    ),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HomePage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => const ComdirectRoute().go(context),
            icon: const Icon(Icons.account_balance),
          ),
          IconButton(
            onPressed: () => const TurnoversRoute().go(context),
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            onPressed: () => const SettingsRoute().go(context),
            icon: const Icon(Icons.settings),
          ),
        ],
        title: const Text('Finanalyze'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
