import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/settings/amazon_order_renderer.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/dialogs/turnover_info_dialog.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/widgets/plain_text_renderer.dart';
import 'package:kashr/turnover/widgets/purpose_renderer.dart';

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
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => TurnoverInfoDialog.show(context, widget.turnover),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TurnoverInfoCardContent(turnover: widget.turnover),
        ),
      ),
    );
  }
}

class TurnoverInfoCardContent extends StatelessWidget {
  const TurnoverInfoCardContent({
    super.key,
    required this.turnover,
    this.showDetails = false,
  });

  final Turnover turnover;
  final bool showDetails;

  /// Chain of purpose renderers to try in order.
  /// First renderer that can handle the text will be used.
  static const _renderers = <PurposeRenderer>[
    AmazonOrderRenderer(),
    PlainTextRenderer(),
  ];

  /// Renders the purpose text using the first applicable renderer.
  Widget _buildPurposeText(
    BuildContext context,
    String text,
    TextStyle? style, {
    int? maxLines,
    TextOverflow? overflow,
  }) {
    for (final renderer in _renderers) {
      final widget = renderer.tryRender(
        context,
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
      if (widget != null) {
        return widget;
      }
    }

    // Fallback (should never reach here due to PlainTextRenderer)
    return Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }

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
              Expanded(
                child: Text(
                  state.accountById[turnover.accountId]?.name ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          turnover.counterPart ?? '(Unknown)',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        _buildPurposeText(
          context,
          turnover.purpose,
          theme.textTheme.bodyMedium,
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
            Text(
              turnover.formatDate(context.dateFormat) ?? '',
              style: theme.textTheme.bodySmall,
            ),
            Flexible(
              child: Text(
                turnover.formatAmount(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).decimalColor(turnover.amountValue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
