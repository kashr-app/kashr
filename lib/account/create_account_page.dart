import 'package:decimal/decimal.dart';
import 'package:kashr/account/accounts_page.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

class CreateAccountRoute extends GoRouteData with $CreateAccountRoute {
  const CreateAccountRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CreateAccountPage();
  }
}

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'To create synced accounts, login to comdirect. '
                'On the first data sync it will automatically create the accounts.',
              ),
              const SizedBox(height: 16),
              Text(
                'Here you can create an account with manually tracked transactions.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g., Cash, Checking',
                  border: OutlineInputBorder(),
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
        ),
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
        openingBalanceDate: DateTime.now(),
        isHidden: _isHidden,
      );

      await context.read<AccountCubit>().addAccount(account);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
        const AccountsRoute().go(context);
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
}
