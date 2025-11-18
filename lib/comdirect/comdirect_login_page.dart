import 'package:finanalyzer/comdirect/comdirect_model.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/comdirect/password_field_with_visibility_toggle.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ComdirectLoginRoute extends GoRouteData with $ComdirectLoginRoute {
  const ComdirectLoginRoute({this.from});
  final String? from;
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ComdirectLoginPage();
  }
}

class ComdirectLoginPage extends StatefulWidget {
  const ComdirectLoginPage({super.key});

  @override
  State<ComdirectLoginPage> createState() => _ComdirectLoginPageState();
}

class _ComdirectLoginPageState extends State<ComdirectLoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Credentials _toCredentials() => Credentials(
    clientId: _clientIdController.text,
    clientSecret: _clientSecretController.text,
    username: _usernameController.text,
    password: _passwordController.text,
  );

  Future<void> _loadCredentials() async {
    final credentials = await Credentials.load();
    if (null == credentials) {
      return;
    }
    setState(() {
      _clientIdController.text = credentials.clientId;
      _clientSecretController.text = credentials.clientSecret;
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comdirect Login')),
      body: BlocConsumer<ComdirectAuthCubit, ComdirectAuthState>(
        listener: (context, state) {
          switch (state) {
            case AuthInitial():
            case AuthLoading():
            case WaitingForTANConfirmation():
              break;
            case AuthError():
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
              break;
            case AuthSuccess():
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Login successfull")),
              );
              context.pop();
          }
        },
        builder: (context, state) {
          switch (state) {
            case AuthLoading():
              final msg = state.message;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  if (msg != null) Text(msg),
                ],
              );
            case AuthSuccess():
              // typically the user should not see this, because the moment the success state is emitted
              // the Bloc listener above will pop the screen. But this only happens when the state is emitted.
              // If the state is already successfull when entering the screen, the user will see this UI here.
              return Column(
                children: [
                  const Text("You are logged in"),
                  ElevatedButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: const Text("Back"),
                  ),
                ],
              );
            case WaitingForTANConfirmation():
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 24),
                      Text(
                        "Please confirm the login in the Photo Tan App",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            case AuthError():
            case AuthInitial():
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      PasswordFieldWithVisibilityToggle(
                        controller: _clientIdController,
                        label: 'Client ID',
                      ),
                      PasswordFieldWithVisibilityToggle(
                        controller: _clientSecretController,
                        label: 'Client Secret',
                      ),
                      PasswordFieldWithVisibilityToggle(
                        controller: _usernameController,
                        label: 'Username',
                      ),
                      PasswordFieldWithVisibilityToggle(
                        controller: _passwordController,
                        label: 'Password',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await _toCredentials().store();
                            },
                            child: const Text('Store credentials'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              await _loadCredentials();
                            },
                            child: const Text('Load credentials'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.read<ComdirectAuthCubit>().login(
                              _toCredentials(),
                            );
                          }
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
