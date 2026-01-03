import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:flutter/material.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/widgets/turnover_info_card.dart';
import 'package:uuid/uuid.dart';

/// Shows the [Turnover] information without allowing editing.
///
/// This is intended to be used in situations where the user wants to
/// understand the details of the Turnover, but where the UI flow would
/// become too complex or unpredictable if editing would be allowed. For
/// example when searching for a matching [TagTurnover] for a transfer,
/// they can just review the source Turnover information via this dialog.
class TurnoverInfoDialog extends StatelessWidget {
  final Turnover turnover;
  const TurnoverInfoDialog(this.turnover, {super.key});

  static Future<void> show(BuildContext context, Turnover turnover) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return TurnoverInfoDialog(turnover);
      },
    );
  }

  static Future<void> showById(
    BuildContext context,
    UuidValue turnoverId,
  ) async {
    final repo = context.read<TurnoverRepository>();
    final turnover = await repo.getTurnoverById(turnoverId);
    if (!context.mounted) {
      return;
    }
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return turnover == null
            ? AlertDialog(
                content: Text('Turnover not found'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Ok"),
                  ),
                ],
              )
            : TurnoverInfoDialog(turnover);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.code),
          label: Text('Raw API data'),
          onPressed: () => _showRawApiDataDialog(context),
        ),
        TextButton(
          child: Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      scrollable: true,
      content: TurnoverInfoCardContent(turnover: turnover, showDetails: true),
    );
  }

  void _showRawApiDataDialog(BuildContext context) {
    final apiRaw = turnover.apiRaw;
    String displayContent;

    if (apiRaw == null) {
      displayContent = 'No raw content recorded for this turnover.';
    } else {
      // Try to format as JSON
      try {
        final jsonData = jsonDecode(apiRaw);
        const encoder = JsonEncoder.withIndent('  ');
        displayContent = encoder.convert(jsonData);
      } catch (e) {
        // Not valid JSON, display as-is
        displayContent = apiRaw;
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => _RawApiDataDialog(content: displayContent),
    );
  }
}

class _RawApiDataDialog extends StatelessWidget {
  final String content;

  const _RawApiDataDialog({required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raw API Data'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
          label: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
