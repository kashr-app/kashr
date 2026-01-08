import 'package:decimal/decimal.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/cubit/turnover_tags_cubit.dart';
import 'package:kashr/turnover/dialogs/account_divergence_confirmation_dialog.dart';
import 'package:kashr/turnover/dialogs/amount_exceeding_confirmation_dialog.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:kashr/turnover/widgets/turnover_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class SelectPendingTagTurnoversPage extends StatefulWidget {
  final Turnover turnover;
  final TurnoverTagsCubit cubit;

  const SelectPendingTagTurnoversPage({
    required this.turnover,
    required this.cubit,
    super.key,
  });

  @override
  State<SelectPendingTagTurnoversPage> createState() =>
      _SelectPendingTagTurnoversPageState();
}

class _SelectPendingTagTurnoversPageState
    extends State<SelectPendingTagTurnoversPage> {
  List<_TagTurnoverWithAccount>? _pendingTurnovers;
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingTurnovers();
  }

  Future<void> _loadPendingTurnovers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();

      final unmatched = await tagTurnoverRepository.getUnmatched();

      // Filter out TagTurnovers that are already associated with this turnover
      final existingTagTurnoverIds = widget
          .cubit
          .state
          .currentTagTurnoversById
          .keys
          .toSet();

      final availableUnmatched = unmatched
          .where((tt) => !existingTagTurnoverIds.contains(tt.id))
          .toList();

      // Combine unmatched and unallocated TagTurnovers
      final allAvailable = [
        ...availableUnmatched,
        ...widget.cubit.state.unallocatedTagTurnovers,
      ];

      final withTagsAndAccounts = allAvailable.map((tt) {
        return _TagTurnoverWithAccount(
          tagTurnover: tt,
          accountId: tt.accountId,
        );
      }).toList();

      setState(() {
        _pendingTurnovers = withTagsAndAccounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending turnovers: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String tagTurnoverId) {
    setState(() {
      if (_selectedIds.contains(tagTurnoverId)) {
        _selectedIds.remove(tagTurnoverId);
      } else {
        _selectedIds.add(tagTurnoverId);
      }
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedIds.isEmpty) return;

    final selectedTurnovers = _pendingTurnovers!
        .where((tt) => _selectedIds.contains(tt.tagTurnover.id.uuid))
        .toList();

    final selectedTagTurnovers = selectedTurnovers
        .map((tt) => tt.tagTurnover)
        .toList();

    // Check for account divergence
    final divergingTagTurnovers = selectedTagTurnovers
        .where((tt) => tt.accountId != widget.turnover.accountId)
        .toList();

    if (divergingTagTurnovers.isNotEmpty) {
      final confirmed = await AccountDivergenceConfirmationDialog.show(
        context,
        divergingTagTurnovers: divergingTagTurnovers,
        targetAccountId: widget.turnover.accountId,
      );

      if (confirmed != true) return;
    }

    // Check for amount exceeding
    final check = widget.cubit.state.checkIfWouldExceed(selectedTagTurnovers);
    if (check.wouldExceed) {
      if (!mounted) return;

      final action = await AmountExceedingConfirmationDialog.show(
        context,
        totalAmount: check.combinedTotal,
        turnoverAmount: widget.turnover.amountValue.abs(),
        exceedingAmount: check.exceedingAmount,
        currencyUnit: widget.turnover.amountUnit,
      );

      if (action != AmountExceedingAction.scaleDown) return;
    }

    // All confirmations passed, associate the TagTurnovers
    widget.cubit.allocatePendingTagTurnovers(selectedTagTurnovers);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pending Turnovers'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                'Confirm (${_selectedIds.length})',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            TurnoverInfoCard(turnover: widget.turnover),
            if (_selectedIds.isNotEmpty)
              Container(
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} ${_selectedIds.length == 1 ? 'turnover' : 'turnovers'} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPendingTurnovers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _pendingTurnovers == null || _pendingTurnovers!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending turnovers',
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingTurnovers!.length,
                      itemBuilder: (context, index) {
                        final item = _pendingTurnovers![index];
                        final isSelected = _selectedIds.contains(
                          item.tagTurnover.id.uuid,
                        );
                        final accountDiverges =
                            item.accountId != widget.turnover.accountId;

                        return _SelectablePendingTurnoverItem(
                          tagTurnoverWithTagAndAccount: item,
                          isSelected: isSelected,
                          accountDiverges: accountDiverges,
                          onTap: () =>
                              _toggleSelection(item.tagTurnover.id.uuid),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectablePendingTurnoverItem extends StatelessWidget {
  final _TagTurnoverWithAccount tagTurnoverWithTagAndAccount;
  final bool isSelected;
  final bool accountDiverges;
  final VoidCallback onTap;

  const _SelectablePendingTurnoverItem({
    required this.tagTurnoverWithTagAndAccount,
    required this.isSelected,
    required this.accountDiverges,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = tagTurnoverWithTagAndAccount.tagTurnover;
    final tagId = tt.tagId;
    final accountId = tagTurnoverWithTagAndAccount.accountId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  final tag = tagState.tagById[tagId];
                  return Row(
                    children: [
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.circle_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      TagAvatar(tag: tag, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tt.note ?? tag?.name ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tag?.name ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        tt.formatAmount(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: tt.amountValue < Decimal.zero
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) {
                  final account = state.accountById[accountId];
                  return Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tt.bookingDate.day.toString().padLeft(2, '0')}.${tt.bookingDate.month.toString().padLeft(2, '0')}.${tt.bookingDate.year}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        account?.syncSource?.icon ?? Icons.account_balance,
                        size: 12,
                        color: accountDiverges
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        account?.name ?? 'Unknown Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: accountDiverges
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: accountDiverges
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagTurnoverWithAccount {
  final TagTurnover tagTurnover;
  final UuidValue accountId;

  _TagTurnoverWithAccount({
    required this.tagTurnover,
    required this.accountId,
  });
}
