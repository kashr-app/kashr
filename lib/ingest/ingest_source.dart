import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Where the transactions in Kashr come from.
///
/// [ask] is not a source. It is what the default source setting holds until
/// the user picks one, the same way `AmazonOrderBehavior.askOnTap` is a value
/// of the behaviour it configures.
enum IngestSource {
  ask,
  manual,
  csv,
  bank;

  IconData get icon => switch (this) {
    IngestSource.ask => Icons.help_outline,
    IngestSource.manual => Icons.edit_outlined,
    IngestSource.csv => Icons.upload_file_outlined,
    IngestSource.bank => Icons.account_balance_outlined,
  };

  String get displayName => switch (this) {
    IngestSource.ask => 'Ask every time',
    IngestSource.manual => 'I\'ll enter them myself',
    IngestSource.csv => 'Import a CSV file',
    IngestSource.bank => 'Download from my bank',
  };

  String get description => switch (this) {
    IngestSource.ask => 'Show the options each time.',
    IngestSource.manual => 'For cash, or a bank you\'d rather track by hand.',
    IngestSource.csv => 'Not available yet.',
    IngestSource.bank => 'comdirect. Automatic once connected.',
  };

  /// Whether tapping the download button can go straight here.
  ///
  /// [manual] cannot: it only ever points at the two buttons beside it, so a
  /// button that always lands there does nothing. [csv] joins once it exists.
  bool get canBeDefault => this == IngestSource.bank;

  /// What the default source setting can be set to.
  static Iterable<IngestSource> get settable =>
      values.where((it) => it == ask || it.canBeDefault);
}

class IngestSourceConverter implements JsonConverter<IngestSource, String> {
  const IngestSourceConverter();

  @override
  IngestSource fromJson(String json) => IngestSource.values.firstWhere(
    (e) => e.name == json,
    orElse: () => IngestSource.ask,
  );

  @override
  String toJson(IngestSource object) => object.name;
}

/// Lets the user pick what the add transactions button does when tapped.
Future<IngestSource?> showDefaultIngestSourceDialog(
  BuildContext context,
  IngestSource current,
) {
  return showModalBottomSheet<IngestSource>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'What the add transactions button does when tapped',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ...IngestSource.settable.map((option) {
              return ListTile(
                leading: Icon(option.icon),
                title: Text(option.displayName),
                subtitle: Text(option.description),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
