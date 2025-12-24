import 'package:kashr/analytics/cubit/analytics_cubit.dart';
import 'package:kashr/analytics/cubit/analytics_state.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TagFilterSection extends StatelessWidget {
  const TagFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsCubit, AnalyticsState>(
      builder: (context, state) {
        if (state.allTags.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter by Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.read<AnalyticsCubit>().selectAllTags(),
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.read<AnalyticsCubit>().deselectAllTags(),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.selectedTagIds.length} of ${state.allTags.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.allTags.map((tag) {
                    final isSelected = state.selectedTagIds.any(
                      (id) => id == tag.id,
                    );

                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TagAvatar(tag: tag, radius: 12),
                          const SizedBox(width: 8),
                          Text(tag.name),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) =>
                          context.read<AnalyticsCubit>().toggleTag(tag.id),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
