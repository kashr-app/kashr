import 'package:decimal/decimal.dart';
import 'package:kashr/account/accounts_page.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/settings/banks_page.dart';
import 'package:kashr/app_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

/// Route to the account creation form.
///
/// Push it to get the created [Account] back:
///
/// ```dart
/// final account = await const CreateAccountRoute().push<Account>(context);
/// ```
///
/// The result is `null` when the user left without creating an account.
class CreateAccountRoute extends GoRouteData with $CreateAccountRoute {
  const CreateAccountRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CreateAccountPage();
  }
}

/// Form that creates a single account and pops it to the caller.
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  AccountType _selectedAccountType = AccountType.cash;
  String _selectedCurrency = 'EUR';
  bool _isHidden = false;
  bool _isLoading = false;
  int _openingBalanceScaled = 0;

  /// Whether the user answered the source question with entering transactions
  /// themselves. Until then the page asks where transactions come from.
  bool _entersTransactionsManually = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Going back from the form returns to the source question rather than
      // leaving the flow. Popping with the created account bypasses this.
      canPop: !_entersTransactionsManually,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _entersTransactionsManually = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: SafeArea(
          child: _entersTransactionsManually
              ? _buildManualForm(context)
              : _TransactionSourceStep(
                  onEnterManually: () =>
                      setState(() => _entersTransactionsManually = true),
                  onDownloadFromBank: _chooseBank,
                ),
        ),
      ),
    );
  }

  /// Opens the bank list, and switches to manual entry when the user finds
  /// their bank is not supported yet.
  Future<void> _chooseBank() async {
    final trackManually = await const BanksRoute(
      from: banksFromAccountCreation,
    ).push<bool>(context);

    if (trackManually == true && mounted) {
      setState(() => _entersTransactionsManually = true);
    }
  }

  Widget _buildManualForm(BuildContext context) {
    final accountCount = context.select<AccountCubit, int>(
      (cubit) => cubit.state.accountById.length,
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'You can connect this account to your bank later.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Account Name',
              hintText: accountCount < 2 ? 'e.g., Cash, Checking' : null,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an account name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            initialValue: _selectedAccountType,
            decoration: const InputDecoration(
              labelText: 'Account Type',
              border: OutlineInputBorder(),
            ),
            items: AccountType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(type.icon),
                    const SizedBox(width: 12),
                    Text(type.label()),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedAccountType = value);
              }
            },
          ),
          const SizedBox(height: 16),
          _buildOpeningBalanceField(),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCurrency = value);
              }
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Hidden Account'),
            subtitle: const Text(
              'Hidden accounts won\'t appear in the main list',
            ),
            value: _isHidden,
            onChanged: (value) => setState(() => _isHidden = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _createAccount,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningBalanceField() {
    final currency = Currency.currencyFrom(_selectedCurrency);
    final openingBalance =
        (Decimal.fromInt(_openingBalanceScaled) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 2);
    final displayText = currency.format(openingBalance);

    return InkWell(
      onTap: _showAmountDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Opening Balance',
          border: OutlineInputBorder(),
        ),
        child: Text(displayText, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  Future<void> _showAmountDialog() async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: _selectedCurrency,
      initialAmountScaled: _openingBalanceScaled,
      showSignSwitch: true,
      preferredSign: TurnoverSign.income,
    );

    if (result != null) {
      setState(() {
        _openingBalanceScaled = result;
      });
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final openingBalance =
          (Decimal.fromInt(_openingBalanceScaled) / Decimal.fromInt(100))
              .toDecimal(scaleOnInfinitePrecision: 2);

      final account = Account(
        id: uuid.v4obj(),
        createdAt: DateTime.now(),
        name: _nameController.text,
        accountType: _selectedAccountType,
        syncSource: SyncSource.manual,
        currency: _selectedCurrency,
        openingBalance: openingBalance,
        lastSyncDate: DateTime.now(),
        isHidden: _isHidden,
      );

      await context.read<AccountCubit>().addAccount(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
        _close(account);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create account: ${e.toString()}'),
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

  /// Returns [account] to whoever opened this page.
  ///
  /// Falls back to the accounts list when the page was opened directly, e.g.
  /// via a deep link, and there is nothing to pop back to.
  void _close(Account account) {
    if (context.canPop()) {
      context.pop(account);
    } else {
      const AccountsRoute().go(context);
    }
  }
}

/// Asks where the transactions of the account to create come from.
class _TransactionSourceStep extends StatelessWidget {
  const _TransactionSourceStep({
    required this.onEnterManually,
    required this.onDownloadFromBank,
  });

  final VoidCallback onEnterManually;
  final VoidCallback onDownloadFromBank;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Where do transactions come from?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('I\'ll enter them myself'),
            subtitle: const Text(
              'For cash, or a bank you\'d rather track by hand.',
            ),
            onTap: onEnterManually,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Download from my bank'),
            subtitle: const Text('Connect your bank and download turnovers.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onDownloadFromBank,
          ),
        ),
      ],
    );
  }
}
