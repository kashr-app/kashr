import 'package:kashr/turnover/model/tag_suggestion.dart';
import 'package:flutter/material.dart';

/// Widget displaying a horizontal scrollable row of tag suggestions.
///
/// Each suggestion shows:
/// - Tag name
/// - Confidence indicator (dots)
/// - Suggested amount
/// - Tap to add the tag with the suggested amount
class TagSuggestionsRow extends StatelessWidget {
  final List<TagSuggestion> suggestions;
  final void Function(TagSuggestion suggestion) onSuggestionTap;

  const TagSuggestionsRow({
    required this.suggestions,
    required this.onSuggestionTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Suggested tags',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _SuggestionChip(
                suggestion: suggestion,
                onTap: () => onSuggestionTap(suggestion),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Individual suggestion chip with confidence indicator.
class _SuggestionChip extends StatelessWidget {
  final TagSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionChip({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = _parseColor(suggestion.tag.color);
    final confidence = suggestion.confidence;

    return Material(
      color: tagColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tag avatar/icon
              CircleAvatar(
                radius: 16,
                backgroundColor: tagColor.withValues(alpha: 0.3),
                child: Icon(Icons.label, color: tagColor, size: 18),
              ),
              const SizedBox(width: 8),

              // Tag name
              Text(
                suggestion.tag.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),

              // Confidence indicator (dots)
              _ConfidenceIndicator(confidence: confidence),

              const SizedBox(width: 4),

              // Add icon
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey.shade400;
    }
  }
}

/// Confidence indicator showing 1-3 filled dots.
class _ConfidenceIndicator extends StatelessWidget {
  final SuggestionConfidence confidence;

  const _ConfidenceIndicator({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getConfidenceColor(theme);
    final dotCount = confidence.dotCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            index < dotCount ? Icons.circle : Icons.circle_outlined,
            size: 8,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(ThemeData theme) {
    return switch (confidence) {
      SuggestionConfidence.high => Colors.green,
      SuggestionConfidence.medium => Colors.orange,
      SuggestionConfidence.low => Colors.grey,
    };
  }
}
