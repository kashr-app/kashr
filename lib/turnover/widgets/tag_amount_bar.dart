import 'package:decimal/decimal.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:flutter/material.dart';

/// A horizontal bar widget that visualizes tag amounts as percentages.
/// Each tag's portion is colored according to the tag's color.
/// The remainder (unallocated amount) is shown in grey.
class TagAmountBar extends StatelessWidget {
  final Decimal totalAmount;
  final List<TagTurnoverWithTag> tagTurnovers;
  final double height;

  const TagAmountBar({
    required this.totalAmount,
    required this.tagTurnovers,
    this.height = 24.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Handle edge cases
    if (totalAmount == Decimal.zero) {
      return _buildEmptyBar(context);
    }

    final absoluteTotal = totalAmount.abs();
    final segments = _calculateSegments(absoluteTotal);

    if (segments.isEmpty) {
      return _buildEmptyBar(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: segments.map((segment) {
            return Expanded(
              flex: (segment.percentage * 1000).toInt(),
              child: Container(
                color: segment.color,
                child: segment.percentage > 0.05
                    ? Center(
                        child: Text(
                          '${(segment.percentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _getContrastColor(segment.color),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            'No allocation',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  List<_BarSegment> _calculateSegments(Decimal absoluteTotal) {
    final segments = <_BarSegment>[];
    var allocatedAmount = Decimal.zero;

    // Create segments for each tag
    for (final tagTurnover in tagTurnovers) {
      final amount = tagTurnover.tagTurnover.amountValue.abs();
      final percentage = (amount / absoluteTotal).toDouble();

      if (percentage > 0) {
        final color = _parseColor(tagTurnover.tag.color);
        segments.add(_BarSegment(
          percentage: percentage,
          color: color,
        ));
        allocatedAmount += amount;
      }
    }

    // Add remainder segment if not fully allocated
    final remainder = absoluteTotal - allocatedAmount;
    if (remainder > Decimal.zero) {
      final remainderPercentage = (remainder / absoluteTotal).toDouble();
      segments.add(_BarSegment(
        percentage: remainderPercentage,
        color: Colors.grey.shade300,
      ));
    }

    return segments;
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    try {
      // Remove '#' if present and parse hex color
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey.shade400;
    }
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we should use light or dark text
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _BarSegment {
  final double percentage;
  final Color color;

  _BarSegment({
    required this.percentage,
    required this.color,
  });
}
