import 'package:kashr/core/color_utils.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// Displays a circular avatar for a tag.
///
/// Shows the first letter of the tag name with appropriate colors.
/// If a tag color is provided, uses that color with contrasting text.
/// Otherwise, uses theme colors.
class TagAvatar extends StatelessWidget {
  final Tag? tag;
  final double radius;

  const TagAvatar({required this.tag, this.radius = 16, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tag != null
        ? ColorUtils.parseColor(tag!.color)
        : theme.colorScheme.primary;
    final name = tag?.name ?? '';

    return CircleAvatar(
      radius: radius,
      backgroundColor: color ?? theme.colorScheme.primaryContainer,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.875,
          color: color != null
              ? ColorUtils.getContrastingTextColor(color)
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
