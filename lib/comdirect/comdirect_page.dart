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
              if (isAuthed)
                IconButton(
                  onPressed: () {
                    context.read<ComdirectAuthCubit>().logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logged out successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                )
              else
                IconButton(
                  onPressed: () => const ComdirectLoginRoute().go(context),
                  icon: const Icon(Icons.login),
                  tooltip: 'Login',
                ),
            ],
          ),
          body: SafeArea(
            child: !isAuthed
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Please login to load your Comdirect data"),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            const ComdirectLoginRoute().go(context);
                          },
                          child: const Text("Login"),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "You are logged in.",
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            context.read<ComdirectAuthCubit>().logout();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logged out successfully'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
