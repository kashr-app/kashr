import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the [TagTurnover] information without allowing editing.
///
/// This is intended to be used in situations where the user wants to
/// understand the details of the TagTurnover, but where the UI flow
/// would become too complex or unpredictable if editing would be allowed.
/// For example when searching for a matching TagTurnover for a transfer,
/// the user should not be allowed to enter the TurnoverTagsPage of a
/// candidate where they could change the candidate, as it could result
/// in not being a candidate anymore. The UI flow would than be too
/// complicated. Instead, they should just be able to review the
/// TagTurnover-candidate information via this dialog.
class TagTurnoverInfoDialog {
  static Future<void> show(
    BuildContext context,
    TagTurnover tagTurnover,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
        content: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return BlocBuilder<AccountCubit, AccountState>(
              builder: (context, accountState) {
                return BlocBuilder<TagCubit, TagState>(
                  builder: (context, tagState) {
                    final account =
                        accountState.accountById[tagTurnover.accountId];
                    if (account == null) {
                      return Center(child: Text('Account not found'));
                    }
                    final tag = tagState.tagById[tagTurnover.tagId];
                    if (tag == null) {
                      return Center(child: Text('Tag not found'));
                    }
                    final colorScheme = theme.colorScheme;

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero amount display
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              tagTurnover.format(),
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.decimalColor(
                                  tagTurnover.amountValue,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Booking date
                          Center(
                            child: Text(
                              dateFormat.format(tagTurnover.bookingDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Tag section
                          Text(
                            'TAG',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TagAvatar(tag: tag, radius: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tag.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Account section
                          Text(
                            'ACCOUNT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                account.accountType.icon,
                                size: 24,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  account.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Counterpart section
                          Text(
                            'COUNTERPART',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tagTurnover.counterPart ?? '(Unknown)',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          // Note section
                          Text(
                            'NOTE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ), 
                            child: Text(
                              tagTurnover.note ?? 'N/A',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
