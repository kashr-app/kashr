import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/comdirect/password_field_with_visibility_toggle.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:kashr/app_gate.dart';
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

/// Connects Kashr to comdirect, and says where the credentials end up.
///
/// Saving and signing in are one action. As two buttons they let the user
/// reach two states that do not work: credentials saved but never checked,
/// and a session the next download cannot repeat, because a download loads
/// credentials from storage rather than from this page.
class ComdirectLoginPage extends StatefulWidget {
  const ComdirectLoginPage({super.key});

  @override
  State<ComdirectLoginPage> createState() => _ComdirectLoginPageState();
}

const _unlockFailed = 'Kashr could not unlock your saved credentials.';

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

class _ComdirectLoginPageState extends State<ComdirectLoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Null until the check finishes, so the page never flashes an empty form
  /// at somebody who is already connected.
  bool? _hasStoredCredentials;

  /// Whether the form is up despite stored credentials, to replace them.
  bool _isReplacing = false;

  /// The stop signal of the sign-in in flight, if there is one.
  DownloadCancellation? _loginCancellation;

  @override
  void initState() {
    super.initState();
    _readStoredState();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Reads whether credentials exist without prompting for biometrics, so
  /// that opening the page costs the user nothing.
  Future<void> _readStoredState() async {
    final hasStored = await Credentials.hasStored();
    if (mounted) setState(() => _hasStoredCredentials = hasStored);
  }

  Credentials _toCredentials() => Credentials(
    clientId: _clientIdController.text,
    clientSecret: _clientSecretController.text,
    username: _usernameController.text,
    password: _passwordController.text,
  );

  /// Signs in, with a way to stop the wait for the confirmation.
  ///
  /// Without this the user is held until comdirect gives up, with a spinner
  /// and no way out. The cubit checks the signal only while waiting for that
  /// confirmation, which is the one step long enough to be worth stopping.
  Future<void> _signIn(Credentials credentials) async {
    final cubit = context.read<ComdirectAuthCubit>();
    final cancellation = DownloadCancellation();
    setState(() => _loginCancellation = cancellation);
    try {
      await cubit.login(credentials, cancellation: cancellation);
    } on DownloadCancelledException {
      // The cubit already stepped back to AuthInitial and logged why.
    } finally {
      if (mounted) setState(() => _loginCancellation = null);
    }
  }

  void _cancelSignIn() => _loginCancellation?.cancel();

  /// Saves what was typed, then signs in with it.
  ///
  /// In that order, because a download reads credentials from storage:
  /// signing in without saving leaves the next one with nothing to use. It
  /// also costs one biometric prompt rather than two. A rejected password
  /// leaves the form filled, so correcting it is one edit and one tap.
  Future<void> _connectWithForm() async {
    if (!_formKey.currentState!.validate()) return;

    final credentials = _toCredentials();
    if (!await credentials.store()) {
      if (mounted) {
        Status.error.snack(context, 'Kashr could not save your credentials.');
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _hasStoredCredentials = true;
      _isReplacing = false;
    });
    await _signIn(credentials);
  }

  Future<void> _connectWithStored() async {
    final credentials = await Credentials.load();
    if (!mounted) return;
    if (credentials == null) {
      Status.error.snack(context, _unlockFailed);
      return;
    }
    await _signIn(credentials);
  }

  Future<void> _replaceCredentials() async {
    final credentials = await Credentials.load();
    if (!mounted) return;
    if (credentials == null) {
      Status.error.snack(context, _unlockFailed);
      return;
    }
    setState(() {
      _clientIdController.text = credentials.clientId;
      _clientSecretController.text = credentials.clientSecret;
      _usernameController.text = credentials.username;
      _passwordController.text = credentials.password;
      _isReplacing = true;
    });
  }

  Future<void> _removeCredentials() async {
    final confirmed = await _confirmRemoval(context);
    if (confirmed != true || !mounted) return;

    if (!await Credentials.delete()) {
      if (mounted) {
        Status.error.snack(context, 'Kashr could not remove your credentials.');
      }
      return;
    }
    if (!mounted) return;

    _clientIdController.clear();
    _clientSecretController.clear();
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _hasStoredCredentials = false;
      _isReplacing = false;
    });
  }

  /// Asks before back leaves a confirmation the bank is still waiting on.
  ///
  /// Walking away used to leave the login stuck: the page kept its waiting
  /// state, and a download started afterwards would sit on the same
  /// unanswered confirmation.
  Future<void> _onPopAttempt(bool didPop) async {
    if (didPop) return;
    final router = GoRouter.of(context);
    final abandon = await _confirmAbandoningSignIn(context);
    if (abandon != true) return;
    _cancelSignIn();
    router.pop();
  }

  Future<bool?> _confirmAbandoningSignIn(BuildContext context) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Still signing in'),
          content: const Text(
            'comdirect is waiting for you to confirm this login in your '
            'photoTAN app. Leaving now cancels it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep waiting'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel login'),
            ),
          ],
        ),
      );

  Future<bool?> _confirmRemoval(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove credentials?'),
      content: const Text(
        'Kashr will not be able to download from comdirect until you enter '
        'them again. The transactions it already downloaded stay where they '
        'are.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ComdirectAuthCubit, ComdirectAuthState>(
      listener: (context, state) {
        switch (state) {
          case AuthInitial():
          case AuthLoading():
          case WaitingForTANConfirmation():
            break;
          case AuthError():
            Status.error.snack(context, state.message);
          case AuthSuccess():
            Status.success.snack(context, 'Connected to comdirect');
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: state is! WaitingForTANConfirmation,
          onPopInvokedWithResult: (didPop, _) => _onPopAttempt(didPop),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('comdirect'),
              actions: [
                if (state is AuthSuccess)
                  IconButton(
                    onPressed: () =>
                        context.read<ComdirectAuthCubit>().logout(),
                    icon: const Icon(Icons.logout),
                    tooltip: 'Sign out',
                  ),
              ],
            ),
            body: SafeArea(child: _body(state)),
          ),
        );
      },
    );
  }

  Widget _body(ComdirectAuthState state) => switch (state) {
    AuthLoading() => _BusyView(message: state.message),
    WaitingForTANConfirmation() => _ConfirmationView(onCancel: _cancelSignIn),
    AuthSuccess() => const _ConnectedView(),
    AuthInitial() => _setup(),
    AuthError() => _setup(error: state),
  };

  Widget _setup({AuthError? error}) {
    final hasStored = _hasStoredCredentials;
    if (hasStored == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Offering to connect again with credentials the bank just refused only
    // walks the user into the same error, so a rejection goes to the fields.
    final wasRejected = error?.reason == DownloadFailureReason.badCredentials;

    if (hasStored && !_isReplacing && !wasRejected) {
      return _StoredCredentialsView(
        onConnect: _connectWithStored,
        onReplace: _replaceCredentials,
        onRemove: _removeCredentials,
      );
    }
    return _CredentialsForm(
      formKey: _formKey,
      clientIdController: _clientIdController,
      clientSecretController: _clientSecretController,
      usernameController: _usernameController,
      passwordController: _passwordController,
      onConnect: _connectWithForm,
      wasRejected: wasRejected,
      // Only worth offering while the fields are empty, which is what a
      // rejection of the saved credentials leaves behind.
      onFillFromSaved: hasStored && _clientIdController.text.isEmpty
          ? _replaceCredentials
          : null,
    );
  }
}

/// What already happened to the credentials, wherever they are entered.
///
/// The one question this page has to answer before it may ask for a banking
/// password, so it sits above the fields rather than below them.
class _StorageNote extends StatelessWidget {
  const _StorageNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kashr keeps these in this device\'s secure storage, and '
                'unlocks them with your device lock or biometrics every time '
                'it reads them. They are sent to comdirect and nowhere else. '
                'There is no Kashr server to send them to.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says where the four values come from, for the first-timer facing them.
class _WhereToFindNote extends StatelessWidget {
  const _WhereToFindNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Where do I find these?'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Client ID and Client Secret come from comdirect, not from Kashr. '
            'You request API access once in comdirect\'s online banking and '
            'they issue the pair to you. Username and password are the ones '
            'you already use to sign in to comdirect.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four values, and the one button that saves and checks them together.
class _CredentialsForm extends StatelessWidget {
  const _CredentialsForm({
    required this.formKey,
    required this.clientIdController,
    required this.clientSecretController,
    required this.usernameController,
    required this.passwordController,
    required this.onConnect,
    this.wasRejected = false,
    this.onFillFromSaved,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController clientIdController;
  final TextEditingController clientSecretController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onConnect;

  /// Whether the bank refused what was last sent.
  final bool wasRejected;

  /// Fills the fields from storage, for a user who has to correct saved
  /// credentials rather than type a new set. Null when there is nothing
  /// saved, or when the fields already hold what was typed.
  final VoidCallback? onFillFromSaved;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (wasRejected) ...[
            _RejectedNote(onFillFromSaved: onFillFromSaved),
            const SizedBox(height: 8),
          ],
          const _StorageNote(),
          const SizedBox(height: 8),
          const _WhereToFindNote(),
          const SizedBox(height: 16),
          PasswordFieldWithVisibilityToggle(
            controller: clientIdController,
            label: 'Client ID',
            validator: _required,
          ),
          PasswordFieldWithVisibilityToggle(
            controller: clientSecretController,
            label: 'Client Secret',
            validator: _required,
          ),
          PasswordFieldWithVisibilityToggle(
            controller: usernameController,
            label: 'Username',
            validator: _required,
          ),
          PasswordFieldWithVisibilityToggle(
            controller: passwordController,
            label: 'Password',
            validator: _required,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onConnect, child: const Text('Connect')),
        ],
      ),
    );
  }
}

/// Says the bank refused these, where the user can do something about it.
class _RejectedNote extends StatelessWidget {
  const _RejectedNote({required this.onFillFromSaved});

  final VoidCallback? onFillFromSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onFillFromSaved = this.onFillFromSaved;
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'comdirect did not accept these. Check them and connect '
                    'again.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (onFillFromSaved != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onFillFromSaved,
                  child: const Text('Fill in the saved ones'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Credentials are saved, so there is nothing to type and three things to do.
class _StoredCredentialsView extends StatelessWidget {
  const _StoredCredentialsView({
    required this.onConnect,
    required this.onReplace,
    required this.onRemove,
  });

  final VoidCallback onConnect;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Credentials saved'),
            subtitle: Text('Kashr can sign in to comdirect on this device.'),
          ),
        ),
        const SizedBox(height: 8),
        const _StorageNote(),
        const SizedBox(height: 24),
        FilledButton(onPressed: onConnect, child: const Text('Connect')),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: onReplace,
              child: const Text('Replace credentials'),
            ),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      ],
    );
  }
}

class _BusyView extends StatelessWidget {
  const _BusyView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Confirm the login in your photoTAN app',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

class _ConnectedView extends StatelessWidget {
  const _ConnectedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Connected to comdirect', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
