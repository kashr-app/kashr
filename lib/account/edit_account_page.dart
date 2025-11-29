import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/accounts_page.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class EditAccountRoute extends GoRouteData with $EditAccountRoute {
  final String accountId;

  const EditAccountRoute({required this.accountId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    // Uses the global AccountCubit from the app-level providers
    // This ensures all pages share the same account state
    return EditAccountPage(accountId: accountId);
  }
}

class EditAccountPage extends StatelessWidget {
  final String accountId;

  const EditAccountPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        if (state.status.isLoading && state.accounts.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Account')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final allAccounts = [...state.accounts, ...state.hiddenAccounts];
        final account = allAccounts.cast<Account?>().firstWhere(
          (a) => a?.id?.uuid == accountId,
          orElse: () => null,
        );

        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Account')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Account not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => const AccountsRoute().go(context),
                    child: const Text('Back to Accounts'),
                  ),
                ],
              ),
            ),
          );
        }

        return _EditAccountForm(
          account: account,
          balance: state.balances[accountId],
        );
      },
    );
  }
}

class _EditAccountForm extends StatefulWidget {
  final Account account;
  final Decimal? balance;

  const _EditAccountForm({required this.account, required this.balance});

  @override
  State<_EditAccountForm> createState() => _EditAccountFormState();
}

class _EditAccountFormState extends State<_EditAccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final Account _originalAccount;
  late final Decimal? _originalBalance;

  late bool _isHidden;
  late int _currentBalanceScaled;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _originalAccount = widget.account;
    _originalBalance = widget.balance;
    _nameController = TextEditingController(text: widget.account.name);
    _isHidden = widget.account.isHidden ?? false;
    _currentBalanceScaled = widget.balance != null
        ? (widget.balance! * Decimal.fromInt(100)).toBigInt().toInt()
        : 0;
  }

  bool get _isDirty {
    final nameChanged = _nameController.text != _originalAccount.name;
    final isHiddenChanged = _isHidden != (_originalAccount.isHidden ?? false);

    final balanceChanged = switch (_originalAccount.syncSource) {
      SyncSource.comdirect => false,
      SyncSource.manual || null =>
        _originalBalance != null &&
            _currentBalanceScaled !=
                (_originalBalance * Decimal.fromInt(100)).toBigInt().toInt(),
    };

    return nameChanged || isHiddenChanged || balanceChanged;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Account'),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _confirmDelete),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAccountInfo(),
              const SizedBox(height: 24),
              _buildNameField(),
              const SizedBox(height: 16),
              _buildBalanceSection(context),
              const SizedBox(height: 16),
              _buildVisibilitySection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildSaveButton(),
        ),
      ),
    );
  }

  Widget _buildAccountInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _originalAccount.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _originalAccount.accountType.icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _originalAccount.accountType.label(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_originalAccount.identifier != null)
                      Text(
                        _originalAccount.identifier ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
            if (_originalAccount.syncSource != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildSyncSource(_originalAccount.syncSource!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Account Name',
        border: OutlineInputBorder(),
      ),
      // Trigger rebuild to update save button enabled state
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an account name';
        }
        return null;
      },
    );
  }

  Widget _buildVisibilitySection() {
    return Card(
      child: SwitchListTile(
        title: const Text('Hide Account'),
        subtitle: const Text(
          'Hidden accounts are excluded from total balance calculations',
        ),
        secondary: Icon(
          _isHidden ? Icons.visibility_off : Icons.visibility,
          color: _isHidden
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
        ),
        value: _isHidden,
        onChanged: (value) {
          setState(() {
            _isHidden = value;
          });
        },
      ),
    );
  }

  Widget _buildBalanceSection(BuildContext context) {
    final currency = Currency.currencyFrom(_originalAccount.currency);
    final currentBalance = _originalBalance != null
        ? (Decimal.fromInt(_currentBalanceScaled) / Decimal.fromInt(100))
              .toDecimal(scaleOnInfinitePrecision: 2)
        : null;
    final balanceText = currentBalance != null
        ? currency.format(currentBalance)
        : '...';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              balanceText,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: currentBalance != null && currentBalance < Decimal.zero
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            switch (_originalAccount.syncSource) {
              SyncSource.comdirect => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance Syncing',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This account\'s balance is automatically synced from '
                    'Comdirect when you download bank data.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              SyncSource.manual || null => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Balance',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to enter the current real balance, then click Save.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _buildBalanceInputField(),
                  const SizedBox(height: 8),
                  Text(
                    'This adjusts the opening balance to match reality. The underlying logic is: opening balance + all turnovers = current balance. '
                    'If you later add turnovers for the past, the balance will change and diverge from reality.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return FilledButton(
      onPressed: (_isLoading || !_isDirty) ? null : _saveAccount,
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save Changes'),
    );
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nameChanged = _nameController.text != _originalAccount.name;
      final isHiddenChanged = _isHidden != (_originalAccount.isHidden ?? false);
      final accountRepository = context.read<AccountRepository>();
      final accountCubit = context.read<AccountCubit>();

      var needsReload = false;

      if (nameChanged || isHiddenChanged) {
        final updatedAccount = _originalAccount.copyWith(
          name: _nameController.text,
          isHidden: _isHidden,
        );
        await accountRepository.updateAccount(updatedAccount);
        needsReload = true;
      }

      switch (_originalAccount.syncSource) {
        case SyncSource.comdirect:
          // Balance is automatically synced, no manual update needed
          break;
        case SyncSource.manual:
        case null:
          final balanceChanged =
              _originalBalance != null &&
              _currentBalanceScaled !=
                  (_originalBalance * Decimal.fromInt(100)).toBigInt().toInt();

          if (balanceChanged) {
            final newBalance =
                (Decimal.fromInt(_currentBalanceScaled) / Decimal.fromInt(100))
                    .toDecimal(scaleOnInfinitePrecision: 2);
            await accountCubit.updateBalanceFromReal(
              _originalAccount,
              newBalance,
            );
            needsReload = false; // updateBalanceFromReal already reloads
          }
          break;
      }

      // Reload accounts if needed to ensure the UI is up-to-date
      if (needsReload) {
        await accountCubit.loadAccounts();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully')),
        );
        const AccountsRoute().go(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update account: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBalanceInputField() {
    final currency = Currency.currencyFrom(_originalAccount.currency);
    final balance =
        (Decimal.fromInt(_currentBalanceScaled) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 2);
    final displayText = currency.format(balance);

    return InkWell(
      onTap: _showBalanceAmountDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Current Real Balance',
          border: OutlineInputBorder(),
        ),
        child: Text(displayText, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  Future<void> _showBalanceAmountDialog() async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: _originalAccount.currency,
      initialAmountScaled: _currentBalanceScaled,
    );

    if (result != null) {
      setState(() {
        _currentBalanceScaled = result;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          'Are you sure you want to delete "${_originalAccount.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final accountCubit = context.read<AccountCubit>();
      await accountCubit.deleteAccount(_originalAccount);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account deleted')));
        const AccountsRoute().go(context);
      }
    }
  }

  Widget _buildSyncSource(SyncSource source) {
    switch (source) {
      case SyncSource.comdirect:
        return Row(
          children: [
            Icon(
              Icons.sync,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Synced with Comdirect',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        );
      case SyncSource.manual:
        return Row(
          children: [
            Icon(
              Icons.sync_disabled,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Manual Transactions',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        );
    }
  }
}
