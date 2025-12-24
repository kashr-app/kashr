import 'package:kashr/account/model/account_repository.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/dialogs/discard_changes_dialog.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/cubit/turnover_tags_cubit.dart';
import 'package:kashr/turnover/cubit/turnover_tags_state.dart';
import 'package:kashr/turnover/dialogs/add_tag_dialog.dart';
import 'package:kashr/turnover/dialogs/delete_turnover_dialog.dart';
import 'package:kashr/turnover/dialogs/edit_turnover_dialog.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:kashr/turnover/tag_turnovers_page.dart';
import 'package:kashr/turnover/transfer_editor_page.dart';
import 'package:kashr/turnover/widgets/select_from_pending_tag_turnovers_hint.dart';
import 'package:kashr/turnover/widgets/source_card.dart';
import 'package:kashr/turnover/widgets/status_message.dart';
import 'package:kashr/turnover/widgets/tag_suggestions_row.dart';
import 'package:kashr/turnover/widgets/tag_turnover_item.dart';
import 'package:kashr/turnover/widgets/turnover_info_card.dart';
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
        context.read<TurnoverRepository>(),
        context.read<AccountRepository>(),
        context.read<TransferRepository>(),
        context.read<TagRepository>(),
        context.read<LogService>().log,
      )..loadTurnover(UuidValue.fromString(turnoverId)),
      child: const TurnoverTagsPage(),
    );
  }
}

class TurnoverTagsPage extends StatelessWidget {
  const TurnoverTagsPage({super.key});

  Future<void> _handleTransferAction(
    BuildContext context,
    TagTurnover tagTurnover,
  ) async {
    final cubit = context.read<TurnoverTagsCubit>();
    final transferDetails = cubit.state.transferByTagTurnoverId[tagTurnover.id];
    final tagRepository = context.read<TagRepository>();
    final tagById = await tagRepository.getByIdsCached();
    final tag = tagById[tagTurnover.tagId];
    final isTransferTag = tag?.isTransfer ?? false;
    final isUnlinkedTransfer = isTransferTag && transferDetails == null;

    if (!context.mounted) return;

    if (transferDetails != null) {
      // Navigate to TransferEditorPage if transfer exists
      await TransferEditorRoute(
        transferId: transferDetails.transfer.id.uuid,
      ).push(context);
      if (context.mounted) cubit.loadTransfers();
    } else if (isUnlinkedTransfer) {
      // Determine the required sign for the counterpart
      final requiredSign = tagTurnover.sign == TurnoverSign.expense
          ? TurnoverSign.income
          : TurnoverSign.expense;

      // Open TagTurnoversPage for selection with appropriate filters
      final selectedTagTurnover = await TagTurnoversPage.openForSelection(
        context: context,
        header: SourceCard(
          tagTurnover: tagTurnover,
          tag: tag!,
          action: CreateOtherTransferSideButton(
            tagTurnover: tagTurnover,
            tag: tag,
            onCreated: (context, created) => Navigator.pop(context, created),
          ),
        ),
        filter: TagTurnoversFilter(sign: requiredSign),
        lockedFilters: TagTurnoversFilter(
          transferTagOnly: true,
          unfinishedTransfersOnly: true,
          excludeTagTurnoverIds: [tagTurnover.id],
        ),
      );

      if (context.mounted && selectedTagTurnover != null) {
        final transferService = context.read<TransferService>();

        // Create the transfer using the service
        final (transferId, conflict) = await transferService
            .linkTransferTagTurnovers(
              sourceTagTurnover: tagTurnover,
              selectedTagTurnover: selectedTagTurnover,
            );

        if (!context.mounted) return;
        await conflict?.showAsDialog(context);
        if (!context.mounted) return;

        if (transferId != null) {
          // Navigate to transfer editor page for review
          await TransferEditorRoute(transferId: transferId.uuid).push(context);
        }
        if (context.mounted) cubit.loadTransfers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: BlocListener<TurnoverTagsCubit, TurnoverTagsState>(
        listener: (context, state) {
          if (state.status.isError && state.errorMessage != null) {
            state.status.snack(context, state.errorMessage!);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Turnover Tags'),
            actions: [
              BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
                builder: (context, state) {
                  final isLoading = state.status.isLoading;
                  if (isLoading) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1),
                      ),
                    );
                  }

                  if (!state.isManualAccount) return const SizedBox.shrink();

                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Turnover',
                        onPressed: isLoading
                            ? null
                            : () => _showEditDialog(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Turnover',
                        onPressed: isLoading
                            ? null
                            : () => _showDeleteDialog(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
              builder: (context, state) {
                final isLoading = state.status.isLoading;

                final turnover = state.turnover;
                if (turnover == null || isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tagTurnovers = state.currentTagTurnoversById.values
                    .toList();

                return Column(
                  children: [
                    TurnoverInfoCard(turnover: turnover),

                    if (state.status.isError)
                      Container(
                        color: theme.colorScheme.errorContainer,
                        margin: EdgeInsets.symmetric(vertical: 6),
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(16),
                        child: Text(
                          state.errorMessage ?? 'Unknown error',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    // Hint for selecting from pending tag turnovers
                    SelectFromPendingTagTurnoversHint(turnover: turnover),

                    // Tag suggestions
                    TagSuggestionsRow(
                      suggestions: state.suggestions,
                      onSuggestionTap: (suggestion) {
                        context.read<TurnoverTagsCubit>().addTag(
                          suggestion.tag,
                        );
                      },
                    ),

                    // Tag turnovers list
                    Expanded(
                      child: tagTurnovers.isEmpty
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
                          : BlocBuilder<TagCubit, TagState>(
                              builder: (context, tagState) {
                                return ListView.builder(
                                  itemCount: tagTurnovers.length,
                                  itemBuilder: (context, index) {
                                    final tagTurnover = tagTurnovers[index];
                                    final transferDetails =
                                        state
                                            .transferByTagTurnoverId[tagTurnover
                                            .id];
                                    return TagTurnoverItem(
                                      key: ValueKey(tagTurnover.id),
                                      tagTurnover: tagTurnover,
                                      tag:
                                          tagState.tagById[tagTurnover.tagId] ??
                                          Tag(
                                            id: tagTurnover.tagId,
                                            name: '(Unknown)',
                                          ),
                                      maxAmountScaled:
                                          decimalScale(turnover.amountValue) ??
                                          0,
                                      currencyUnit: turnover.amountUnit,
                                      transferWithDetails: transferDetails,
                                      onTransferAction: () =>
                                          _handleTransferAction(
                                            context,
                                            tagTurnover,
                                          ),
                                    );
                                  },
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
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context) async {
    final selectedTag = await AddTagDialog.show(context);
    if (selectedTag != null && context.mounted) {
      context.read<TurnoverTagsCubit>().addTag(selectedTag);
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final cubit = context.read<TurnoverTagsCubit>();
    final turnover = cubit.state.turnover;

    if (turnover == null) return;

    final updatedTurnover = await EditTurnoverDialog.show(
      context,
      turnover: turnover,
    );

    if (updatedTurnover != null && context.mounted) {
      await cubit.updateTurnover(updatedTurnover);
    }
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final option = await DeleteTurnoverDialog.show(context);

    if (option != null && context.mounted) {
      final cubit = context.read<TurnoverTagsCubit>();
      final makePending = option == DeleteTagTurnoversOption.makePending;

      await cubit.deleteTurnover(makePending: makePending);

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
