import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/local_auth/cubit/local_auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part '../_gen/local_auth/local_auth_login_page.g.dart';

@TypedGoRoute<LocalAuthLoginRoute>(
  path: '/auth',
)
class LocalAuthLoginRoute extends GoRouteData with $LocalAuthLoginRoute {
  const LocalAuthLoginRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const LocalAuthLoginPage();
  }
}

class LocalAuthLoginPage extends StatefulWidget {
  const LocalAuthLoginPage({super.key});

  @override
  State<LocalAuthLoginPage> createState() => _LocalAuthLoginPageState();
}

class _LocalAuthLoginPageState extends State<LocalAuthLoginPage> {
  @override
  void initState() {
    super.initState();
    // Trigger authentication as soon as the page is opened unless the user closed the app (logged out).
    if (context.read<LocalAuthCubit>().state is! LocalAuthLoggedOut) {
      _startAuthentication();
    }
  }

  void _startAuthentication() {
    context.read<LocalAuthCubit>().authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Authenticate"),
      ),
      body: BlocBuilder<LocalAuthCubit, LocalAuthState>(
        builder: (context, state) {
          switch (state) {
            case LocalAuthInitial():
            case LocalAuthLoggedOut():
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_circle,
                        color: Theme.of(context).primaryColor, size: 64),
                    const SizedBox(height: 8),
                    const Text(
                      "Welcome",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startAuthentication,
                      child: const Text("Authenticate"),
                    ),
                  ],
                ),
              );
            case LocalAuthLoading():
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    if (state.message != null) ...[
                      const SizedBox(height: 10),
                      Text(state.message!),
                    ],
                  ],
                ),
              );
            case LocalAuthSuccess():

              /// Typically the user should not see this screen
              /// (or only for a single frame) because the app router
              /// will redirect on auth changes automatically.
              /// This here rather acts as a fallback.
              return Column(
                children: [
                  const Text("Login Successfull"),
                  ElevatedButton(
                    onPressed: () {
                      const HomeRoute().go(context);
                    },
                    child: const Text("To home page"),
                  ),
                ],
              );
            case LocalAuthError():
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startAuthentication,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}
