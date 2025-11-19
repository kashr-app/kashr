import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final dateFormat = DateFormat("dd.MM.yyyy");

class ComdirectRoute extends GoRouteData with $ComdirectRoute {
  const ComdirectRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ComdirectPage();
  }
}

class ComdirectPage extends StatelessWidget {
  const ComdirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComdirectAuthCubit, ComdirectAuthState>(
      builder: (context, state) {
        final isAuthed = state is AuthSuccess;
        return Scaffold(
          appBar: AppBar(
            title: const Text("Comdirect"),
            actions: [
              IconButton(
                onPressed: () => const ComdirectLoginRoute().go(context),
                icon: Icon(isAuthed ? Icons.account_circle : Icons.login),
              ),
            ],
          ),
          body: SafeArea(
            child: !isAuthed
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Please login to load your Comdirect data"),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            const ComdirectLoginRoute().go(context);
                          },
                          child: const Text("Login"),
                        ),
                      ],
                    ),
                  )
                : Center(child: Text("You are logged in.")),
          ),
        );
      },
    );
  }
}
