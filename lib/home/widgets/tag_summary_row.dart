import 'package:decimal/decimal.dart';
import 'package:kashr/core/color_utils.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/home/model/tag_prediction.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// A reusable row widget that displays a summary item (tag or unallocated)
/// with a color indicator, name, amount, percentage bar, and tap handler.
class TagSummaryRow extends StatelessWidget {
  final Tag? tag;
  final bool isUnallocated;
  final Decimal amount;
  final Decimal totalAmount;
  final Currency currency;
  final Period period;
  final TagPrediction? prediction;
  final VoidCallback? onTap;

  const TagSummaryRow({
    this.tag,
    this.isUnallocated = false,
    required this.amount,
    required this.totalAmount,
    required this.currency,
    required this.period,
    this.prediction,
    this.onTap,
    super.key,
  }) : assert(
         tag != null || isUnallocated,
         'Either tag must be provided or isUnallocated must be true',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor();
    final label = _getLabel();
    final percentage = _calculatePercentage();
    final (avg, avgPerUnit) = period.avgPerFullPeriod(amount);
    final isCurrentPeriod = period.contains(DateTime.now());

    final textColor = Color.lerp(color, theme.colorScheme.onSurface, 0.4)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: isUnallocated
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        Text(
                          currency.format(amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: color,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (prediction != null && isCurrentPeriod)
                          InkWell(
                            onTap: () => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Ok'),
                                  ),
                                ],
                                title: Text('Prediction'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${currency.format(prediction!.averageFromHistory)} is the average of the last'
                                      ' ${prediction!.periodsAnalyzed} period(s) with data for tag "${tag?.name}".',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: textColor.withValues(alpha: 0.5),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Predicted ${currency.format(prediction!.averageFromHistory)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: textColor.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'AVG ${isCurrentPeriod ? 'so far ' : ''}${currency.format(avg)} / $avgPerUnit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 45,
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    if (isUnallocated) {
      return Colors.grey.shade400;
    }

    final colorString = tag?.color;
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    return ColorUtils.parseColor(colorString) ?? Colors.grey.shade400;
  }

  String _getLabel() {
    if (isUnallocated) {
      return 'Unallocated';
    }
    return tag?.name ?? 'Unknown';
  }

  double _calculatePercentage() {
    if (totalAmount == Decimal.zero) {
      return 0.0;
    }
    return (amount.abs() / totalAmount.abs()).toDouble() * 100;
  }
}
