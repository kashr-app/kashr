import 'dart:convert';

import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
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
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

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
    final theme = Theme.of(context);
    final iban = widget.turnover.counterIban;

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) => Row(
                  children: [
                    Icon(
                      state.accountById[widget.turnover.accountId]
                          ?.accountType.icon,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.accountById[widget.turnover.accountId]?.name ?? '',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.turnover.counterPart ?? '(Unknown)',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.turnover.purpose,
                style: theme.textTheme.bodyMedium,
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
              if (_isExpanded && iban != null) ...[
                const SizedBox(height: 4),
                Text(iban, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.turnover.formatDate() ?? '',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    widget.turnover.formatAmount(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .decimalColor(widget.turnover.amountValue),
                    ),
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.code),
                      onPressed: () => _showRawApiDataDialog(context),
                      tooltip: 'View raw API data',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
          child: const Text('Copy All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
