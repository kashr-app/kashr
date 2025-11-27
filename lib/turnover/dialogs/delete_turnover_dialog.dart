import 'package:flutter/material.dart';

enum DeleteTagTurnoversOption {
  delete,
  makePending,
}

class DeleteTurnoverDialog extends StatefulWidget {
  const DeleteTurnoverDialog({super.key});

  static Future<DeleteTagTurnoversOption?> show(BuildContext context) {
    return showDialog<DeleteTagTurnoversOption>(
      context: context,
      builder: (context) => const DeleteTurnoverDialog(),
    );
  }

  @override
  State<DeleteTurnoverDialog> createState() => _DeleteTurnoverDialogState();
}

class _DeleteTurnoverDialogState extends State<DeleteTurnoverDialog> {
  DeleteTagTurnoversOption _selectedOption =
      DeleteTagTurnoversOption.makePending;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Turnover'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to delete this turnover?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          const Text(
            'What should happen to the associated tag assignments?',
          ),
          const SizedBox(height: 12),
          RadioGroup<DeleteTagTurnoversOption>(
            groupValue: _selectedOption,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedOption = value;
                });
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<DeleteTagTurnoversOption>(
                  title: const Text('Make them pending'),
                  subtitle: const Text(
                    'Tag assignments will become unmatched and can be linked to other turnovers',
                  ),
                  value: DeleteTagTurnoversOption.makePending,
                ),
                RadioListTile<DeleteTagTurnoversOption>(
                  title: const Text('Delete them'),
                  subtitle: const Text(
                    'All tag assignments will be permanently deleted',
                  ),
                  value: DeleteTagTurnoversOption.delete,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedOption),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
