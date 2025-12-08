import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class AccountSelectorDialog extends StatelessWidget {
  final UuidValue? selectedId;
  const AccountSelectorDialog({super.key, this.selectedId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Select Account'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.visibleAccounts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SwitchListTile(
                    title: Text('Show hidden'),
                    value: state.showHiddenAccounts,
                    onChanged: (_) =>
                        context.read<AccountCubit>().toggleHiddenAccounts(),
                  );
                }
                final account = state.visibleAccounts[index - 1];
                final isSelected = account.id == selectedId;
                return ListTile(
                  selected: isSelected,
                  leading: Icon(account.accountType.icon),
                  title: Text(account.name),
                  subtitle: Text(account.accountType.label()),
                  onTap: () => Navigator.of(context).pop(account),
                  trailing: isSelected ? Icon(Icons.check) : null,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
