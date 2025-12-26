import 'package:flutter/material.dart';

class DashboardHint extends StatelessWidget {
  const DashboardHint({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.colorBackground,
    required this.onTap,
    this.size = 18,
  });

  final Widget icon;
  final double size;

  final String title;
  final Color color;
  final Color colorBackground;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: colorBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (icon is Icon)
                  Icon((icon as Icon).icon, size: size, color: color)
                else
                  icon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
