import 'package:flutter/material.dart';
import 'package:kashr/ingest/ingest_source.dart';

/// One way of getting transactions into Kashr, offered as a card.
///
/// The wording lives on [IngestSource] rather than here, so the account
/// creation wizard and the download button describe the same option the same
/// way without either having to know about the other.
class IngestSourceTile extends StatelessWidget {
  const IngestSourceTile({
    super.key,
    required this.source,
    required this.onTap,
    this.trailing,
  });

  final IngestSource source;
  final VoidCallback onTap;

  /// Replaces the chevron, for a caller that has something better to put
  /// there.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(source.icon),
        title: Text(source.displayName),
        subtitle: Text(source.description),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
