import 'package:finanalyzer/account/model/account.dart';
import 'package:flutter/material.dart';
class DualAccountSelectorDialog extends StatefulWidget {
  final List<Account> accounts;

  const DualAccountSelectorDialog({super.key, required this.accounts});

  @override
  State<DualAccountSelectorDialog> createState() =>
      _DualAccountSelectorDialogState();
}

class _DualAccountSelectorDialogState
    extends State<DualAccountSelectorDialog> {
  Account? from;
  Account? to;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Transfer Between Accounts"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSection(
              context: context,
              label: "From",
              selected: from,
              onSelected: (account) => setState(() {
                from = account;
                if (to == account) to = null;
              }),
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              label: "To",
              selected: to,
              onSelected: (account) => setState(() {
                to = account;
                if (from == account) from = null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: (from != null && to != null)
              ? () => Navigator.pop(
                    context,
                    TransferAccountSelection(from: from!, to: to!),
                  )
              : null,
          child: const Text("Continue"),
        ),
      ],
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String label,
    required Account? selected,
    required ValueChanged<Account> onSelected,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 150,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: widget.accounts.length,
                itemBuilder: (context, index) {
                  final account = widget.accounts[index];
                  final isSelected = account == selected;
                  final cs = theme.colorScheme;
              
                  return ListTile(
                    leading: Icon(
                      account.accountType.icon,
                      color: theme.iconTheme.color,
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.accountType.label()),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: cs.primary)
                        : null,
                    tileColor: isSelected
                        ? cs.primary.withValues(alpha: 0.08)
                        : null,
                    onTap: () => onSelected(account),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class TransferAccountSelection {
  final Account from;
  final Account to;

  TransferAccountSelection({required this.from, required this.to});
}
