import 'dart:convert';

import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays information about a turnover in a card format.
///
/// Shows the counter party, purpose, date, and formatted amount.
/// The card can be expanded to show additional details like IBAN and raw API
/// data.
class TurnoverInfoCard extends StatefulWidget {
  final Turnover turnover;

  const TurnoverInfoCard({required this.turnover, super.key});

  @override
  State<TurnoverInfoCard> createState() => _TurnoverInfoCardState();
}

class _TurnoverInfoCardState extends State<TurnoverInfoCard> {
  void _showRawApiDataDialog(BuildContext context) {
    final apiRaw = widget.turnover.apiRaw;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
            content: _TurnoverInfoCardContent(
              turnover: widget.turnover,
              showDetails: true,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _TurnoverInfoCardContent(turnover: widget.turnover),
        ),
      ),
    );
  }
}

class _TurnoverInfoCardContent extends StatelessWidget {
  const _TurnoverInfoCardContent({
    required this.turnover,
    this.showDetails = false,
  });

  final Turnover turnover;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iban = turnover.counterIban;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<AccountCubit, AccountState>(
          builder: (context, state) => Row(
            children: [
              Icon(
                state.accountById[turnover.accountId]?.accountType.icon,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(state.accountById[turnover.accountId]?.name ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          turnover.counterPart ?? '(Unknown)',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          turnover.purpose,
          style: theme.textTheme.bodyMedium,
          maxLines: showDetails ? null : 3,
          overflow: showDetails ? null : TextOverflow.ellipsis,
        ),
        if (showDetails && iban != null) ...[
          const SizedBox(height: 16),
          Text(
            'IBAN',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Text(iban, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(turnover.formatDate() ?? '', style: theme.textTheme.bodySmall),
            Text(
              turnover.formatAmount(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).decimalColor(turnover.amountValue),
              ),
            ),
          ],
        ),
      ],
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
