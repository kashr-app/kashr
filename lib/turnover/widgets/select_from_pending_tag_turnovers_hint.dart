import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/select_pending_tag_turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectFromPendingTagTurnoversHint extends StatelessWidget {
  final Turnover turnover;

  const SelectFromPendingTagTurnoversHint({
    required this.turnover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tagTurnoverRepository = context.read<TagTurnoverRepository>();

    return BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
      builder: (context, state) {
        return _HintContent(
          turnover: turnover,
          tagTurnoverRepository: tagTurnoverRepository,
          existingTagTurnoverIds: state.tagTurnovers
              .map((tt) => tt.tagTurnover.id?.uuid)
              .whereType<String>()
              .toSet(),
        );
      },
    );
  }
}

class _HintContent extends StatelessWidget {
  final Turnover turnover;
  final TagTurnoverRepository tagTurnoverRepository;
  final Set<String> existingTagTurnoverIds;

  const _HintContent({
    required this.turnover,
    required this.tagTurnoverRepository,
    required this.existingTagTurnoverIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<TagTurnover>>(
      future: tagTurnoverRepository.getUnmatched(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        // Filter out tag turnovers that are already associated with this turnover
        final availablePendingTurnovers = snapshot.data!
            .where((tt) => !existingTagTurnoverIds.contains(tt.id?.uuid))
            .toList();

        if (availablePendingTurnovers.isEmpty) {
          return const SizedBox.shrink();
        }

        final count = availablePendingTurnovers.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Material(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _onTap(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_outlined,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select from ($count) pending ${count == 1 ? 'turnover' : 'turnovers'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final cubit = context.read<TurnoverTagsCubit>();

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SelectPendingTagTurnoversPage(
          turnover: turnover,
          cubit: cubit,
        ),
      ),
    );
  }
}
