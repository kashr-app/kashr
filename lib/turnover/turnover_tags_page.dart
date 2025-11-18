import 'package:finanalyzer/core/dialogs/discard_changes_dialog.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/dialogs/add_tag_dialog.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/widgets/status_message.dart';
import 'package:finanalyzer/turnover/widgets/tag_turnover_item.dart';
import 'package:finanalyzer/turnover/widgets/turnover_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class TurnoverTagsRoute extends GoRouteData with $TurnoverTagsRoute {
  final String turnoverId;
  const TurnoverTagsRoute({required this.turnoverId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (context) => TurnoverTagsCubit(
        context.read<TagTurnoverRepository>(),
        context.read<TagRepository>(),
        context.read<TurnoverRepository>(),
      )..loadTurnover(UuidValue.fromString(turnoverId)),
      child: TurnoverTagsPage(),
    );
  }
}

class TurnoverTagsPage extends StatelessWidget {
  const TurnoverTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final cubit = context.read<TurnoverTagsCubit>();
        if (!cubit.state.isDirty) {
          Navigator.of(context).pop();
          return;
        }

        final shouldDiscard = await DiscardChangesDialog.show(context);
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(title: const Text('Turnover Tags')),
          body: BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
            builder: (context, state) {
              final turnover = state.turnover;
              if (turnover == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  TurnoverInfoCard(turnover: turnover),

                  // Tag turnovers list
                  Expanded(
                    child: state.tagTurnovers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('No tags assigned yet'),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () => _showAddTagDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Tag'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.tagTurnovers.length,
                            itemBuilder: (context, index) {
                              final tagTurnover = state.tagTurnovers[index];
                              return TagTurnoverItem(
                                tagTurnoverWithTag: tagTurnover,
                                maxAmountScaled:
                                    (turnover.amountValue.toDouble() * 100)
                                        .toInt(),
                                currencyUnit: turnover.amountUnit,
                              );
                            },
                          ),
                  ),

                  // Status message and save button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: StatusMessage(
                            state: state,
                            turnover: turnover,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _showAddTagDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Tag'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    (state.isAmountExceeded || !state.isDirty)
                                    ? null
                                    : () async {
                                        await context
                                            .read<TurnoverTagsCubit>()
                                            .saveAll();
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          AddTagDialog(cubit: context.read<TurnoverTagsCubit>()),
    );
  }
}
