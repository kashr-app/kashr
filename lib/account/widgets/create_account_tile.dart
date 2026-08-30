import 'package:flutter/material.dart';
import 'package:kashr/account/create_account_page.dart';
import 'package:kashr/account/model/account.dart';

/// Picker row that opens the account creation flow.
///
/// The created account is reported through [onCreated] so the picker can
/// select it and the user can carry on with what they were doing.
class CreateAccountTile extends StatelessWidget {
  const CreateAccountTile({required this.onCreated, super.key});

  final ValueChanged<Account> onCreated;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.add),
      title: const Text('Create account'),
      onTap: () => _createAccount(context),
    );
  }

  /// Opens the creation flow on the navigator that hosts the picker, so that
  /// it shows up above the picker no matter which navigator that is.
  Future<void> _createAccount(BuildContext context) async {
    final account = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => const CreateAccountPage()),
    );

    if (account != null && context.mounted) {
      onCreated(account);
    }
  }
}
