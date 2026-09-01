import 'package:flutter/material.dart';

/// Says that CSV import is not built yet.
///
/// A dead end, so it is a dialog rather than a sheet: there is nothing to go
/// on to. It promises the price because that promise is the reason the
/// feature exists - CSV is what keeps the data from being locked in.
Future<void> showCsvImportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.upload_file_outlined),
      title: const Text('Not available yet'),
      content: const Text(
        'Importing transactions from a CSV file is planned, and it will stay '
        'free when it lands.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
