import 'package:kashr/home/home_page.dart';
import 'package:kashr/local_auth/cubit/local_auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

part '../_gen/local_auth/local_auth_login_page.g.dart';

@TypedGoRoute<LocalAuthLoginRoute>(path: '/auth')
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
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors
                .white // because the logo slogan does not work well on grey
          : null,
      body: SafeArea(
        child: BlocBuilder<LocalAuthCubit, LocalAuthState>(
          builder: (context, state) {
            switch (state) {
              case LocalAuthInitial():
              case LocalAuthLoggedOut():
                return _buildBody(context);
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
              case LocalAuthError(:String message, :var code):
                return _buildBody(context, error: message, errorCode: code);
            }
          },
        ),
      ),
    );
  }

  Center _buildBody(
    BuildContext context, {
    String? error,
    LocalAuthExceptionCode? errorCode,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Center(
      child: Column(
        children: [
          Expanded(child: Image.asset('assets/logo-transparent.png')),
          if (error != null || errorCode != null) ...[
            Icon(Icons.error, color: errorColor, size: 32),
            const SizedBox(height: 8),
            Text(
              errorCode?.name ?? error ?? 'Unknown error.',
              textAlign: TextAlign.center,
              style: TextStyle(color: errorColor),
            ),
            const SizedBox(height: 32),
          ],
          Column(
            children: [
              Text('Authenticate to enter the app'),
              SizedBox(height: 16),
              FilledButton(
                onPressed: _startAuthentication,
                child: const Text("Authenticate"),
              ),
            ],
          ),
          SizedBox(height: 64),
        ],
      ),
    );
  }
}
