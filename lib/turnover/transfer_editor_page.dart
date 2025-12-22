import 'package:finanalyzer/account/account_selector_dialog.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/logging/services/log_service.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/cubit/transfer_editor_cubit.dart';
import 'package:finanalyzer/turnover/cubit/transfer_editor_state.dart';
import 'package:finanalyzer/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnovers_filter.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/services/transfer_service.dart';
import 'package:finanalyzer/turnover/tag_turnovers_page.dart';
import 'package:finanalyzer/turnover/widgets/quick_turnover_entry_sheet.dart';
import 'package:finanalyzer/turnover/widgets/source_card.dart';
import 'package:finanalyzer/turnover/widgets/transfer_metadata_section.dart';
import 'package:finanalyzer/turnover/widgets/transfer_side_card.dart';
import 'package:finanalyzer/turnover/widgets/transfer_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class TransferEditorRoute extends GoRouteData with $TransferEditorRoute {
  final String transferId;

  const TransferEditorRoute({required this.transferId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TransferEditorPage(transferId: UuidValue.fromString(transferId));
  }
}

class TransferEditorPage extends StatelessWidget {
  final UuidValue? transferId;

  const TransferEditorPage({super.key, required this.transferId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TransferEditorCubit(
        context.read<LogService>().log,
        transferService: context.read<TransferService>(),
        transferRepository: context.read<TransferRepository>(),
        tagTurnoverRepository: context.read<TagTurnoverRepository>(),
        transferId: transferId,
      ),
      child: const _TransferEditorView(),
    );
  }
}

class _TransferEditorView extends StatelessWidget {
  const _TransferEditorView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferEditorCubit, TransferEditorState>(
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: SafeArea(
            child: state.when(
              initial: () => const SizedBox.shrink(),
              loading: () => const Center(child: CircularProgressIndicator()),
              loaded: (details) => _TransferEditorContent(details: details),
              error: (message) => _ErrorView(message: message),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, TransferEditorState state) {
    return state.when(
      initial: () => AppBar(title: const Text('Edit Transfer')),
      loading: () => AppBar(title: const Text('Edit Transfer')),
      loaded: (details) => AppBar(
        title: Text('Edit Transfer'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: 'Delete Transfer',
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
      error: (message) => AppBar(title: const Text('Edit Transfer')),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final cubit = context.read<TransferEditorCubit>();

    // For existing transfers, confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete this transfer?'),
            SizedBox(height: 8),
            Text(
              'This will NOT delete the transactions. They will get unlinked.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.delete();

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Transfer deleted')));
          Navigator.of(context).pop(false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete transfer')),
          );
        }
      }
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferEditorCubit>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: cubit.reload, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TransferEditorContent extends StatelessWidget {
  final TransferWithDetails details;

  const _TransferEditorContent({required this.details});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<AccountCubit, AccountState>(
        builder: (context, accountState) {
          return BlocBuilder<TagCubit, TagState>(
            builder: (context, tagState) {
              final fromAccount =
                  accountState.accountById[details.fromTagTurnover?.accountId];
              final toAccount =
                  accountState.accountById[details.toTagTurnover?.accountId];

              final fromTag = tagState.tagById[details.fromTagTurnover?.tagId];
              final toTag = tagState.tagById[details.toTagTurnover?.tagId];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TransferStatusBanner(
                    reviewReason: details.needsReview,
                    isConfirmed: details.transfer.confirmed,
                  ),
                  const SizedBox(height: 24),
                  TransferSideCard(
                    tagTurnover: details.fromTagTurnover,
                    tag: fromTag,
                    account: fromAccount,
                    sign: TurnoverSign.expense,
                    onLink: () => _handleLinkSide(
                      context,
                      isFromSide: true,
                      otherSide: details.toTagTurnover,
                      otherSideTag: toTag,
                    ),
                    onCreate: () => _handleCreateSide(
                      context,
                      isFromSide: true,
                      otherSide: details.toTagTurnover,
                      otherSideTag: toTag,
                      otherSideAccount: toAccount,
                    ),
                    onUnlink: details.fromTagTurnover != null
                        ? () => _handleUnlinkSide(context, isFromSide: true)
                        : null,
                    onTap: details.fromTagTurnover != null
                        ? () => _handleEditTagTurnover(
                            context,
                            details.fromTagTurnover!,
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  TransferSideCard(
                    tagTurnover: details.toTagTurnover,
                    tag: toTag,
                    account: toAccount,
                    sign: TurnoverSign.income,
                    onLink: () => _handleLinkSide(
                      context,
                      isFromSide: false,
                      otherSide: details.fromTagTurnover,
                      otherSideTag: fromTag,
                    ),
                    onCreate: () => _handleCreateSide(
                      context,
                      isFromSide: false,
                      otherSide: details.fromTagTurnover,
                      otherSideTag: fromTag,
                      otherSideAccount: fromAccount,
                    ),
                    onUnlink: details.toTagTurnover != null
                        ? () => _handleUnlinkSide(context, isFromSide: false)
                        : null,
                    onTap: details.toTagTurnover != null
                        ? () => _handleEditTagTurnover(
                            context,
                            details.toTagTurnover!,
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  TransferMetadataSection(
                    details: details,
                    onConfirm: () => _handleConfirm(context),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleUnlinkSide(
    BuildContext context, {
    required bool isFromSide,
  }) async {
    final cubit = context.read<TransferEditorCubit>();

    // Confirm unlinking
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Transaction'),
        content: const Text(
          'Are you sure you want to unlink this transaction from the transfer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.unlinkTagTurnover(isFromSide: isFromSide);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Transaction unlinked')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unlink transaction')),
          );
        }
      }
    }
  }

  Future<void> _handleLinkSide(
    BuildContext context, {
    required bool isFromSide,
    required TagTurnover? otherSide,
    required Tag? otherSideTag,
  }) async {
    // Determine the required sign based on which side we're linking
    final requiredSign = isFromSide
        ? TurnoverSign.expense
        : TurnoverSign.income;

    final selected = await TagTurnoversPage.openForSelection(
      context: context,
      header: otherSide != null && otherSideTag != null
          ? SourceCard(tagTurnover: otherSide, tag: otherSideTag)
          : null,
      filter: TagTurnoversFilter(sign: requiredSign),
      lockedFilters: TagTurnoversFilter(
        transferTagOnly: true,
        unfinishedTransfersOnly: true,
        excludeTagTurnoverIds: otherSide != null ? [otherSide.id] : null,
      ),
      allowMultiple: false,
    );

    if (selected != null && context.mounted) {
      await _doLinkeTagTurnover(context, selected);
    }
  }

  Future<void> _doLinkeTagTurnover(BuildContext context, TagTurnover tt) async {
    // Attempt to link the tag turnover
    final cubit = context.read<TransferEditorCubit>();
    final conflict = await cubit.linkTagTurnover(tt);
    if (!context.mounted) return;

    if (conflict == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transfer link updated')));
    } else {
      await conflict.showAsDialog(context);
    }
  }

  Future<void> _handleCreateSide(
    BuildContext context, {
    required bool isFromSide,
    required TagTurnover? otherSide,
    required Tag? otherSideTag,
    required Account? otherSideAccount,
  }) async {
    final selectedAccount = await showDialog<Account>(
      context: context,
      builder: (context) => AccountSelectorDialog(
        title: isFromSide ? 'Select FROM Account' : 'Select TO Account',
        excludeId: otherSideAccount?.id,
      ),
    );

    if (selectedAccount == null || !context.mounted) return;

    // Prefill QuickTurnoverEntrySheet
    final createdTagTurnover = await showModalBottomSheet<TagTurnover>(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuickTurnoverEntrySheet(
        account: selectedAccount,
        prefillFromTagTurnover: otherSide != null
            ? otherSide.copyWith(amountValue: -otherSide.amountValue)
            : null,
        prefillTag: otherSideTag,
      ),
    );

    if (createdTagTurnover != null && context.mounted) {
      await _doLinkeTagTurnover(context, createdTagTurnover);
    }
  }

  Future<void> _handleConfirm(BuildContext context) async {
    final cubit = context.read<TransferEditorCubit>();
    final success = await cubit.confirmTransfer();

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transfer confirmed')));
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to confirm transfer')));
      }
    }
  }

  Future<void> _handleEditTagTurnover(
    BuildContext context,
    TagTurnover tagTurnover,
  ) async {
    final cubit = context.read<TransferEditorCubit>();

    final result = await TagTurnoverEditorDialog.show(
      context,
      tagTurnover: tagTurnover,
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case EditTagTurnoverUpdated():
        final success = await cubit.updateTagTurnover(result.tagTurnover);

        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction updated')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update transaction')),
            );
          }
        }
      case EditTagTurnoverDeleted():
        final success = await cubit.deleteTagTurnover(tagTurnover);

        if (context.mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction deleted')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete transaction')),
            );
          }
        }
    }
  }
}
