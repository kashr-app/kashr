import 'package:flutter/material.dart';

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
}
