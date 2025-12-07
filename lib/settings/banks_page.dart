import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BanksRoute extends GoRouteData with $BanksRoute {
  const BanksRoute({this.from});
  final String? from;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const BanksPage();
  }
}

class BanksPage extends StatelessWidget {
  const BanksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Banks')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text('Comdirect'),
              onTap: () => ComdirectLoginRoute().go(context),
            ),
          ),
        ),
      ),
    );
  }
}
