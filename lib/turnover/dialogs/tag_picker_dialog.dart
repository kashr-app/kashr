import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A dialog for selecting a tag.
///
/// Allows searching existing tags while excluding specified tag IDs.
/// Returns the selected [Tag] or null if cancelled.
class TagPickerDialog extends StatefulWidget {
  final Set<UuidValue> excludeTagIds;
  final String title;
  final String subtitle;

  const TagPickerDialog({
    super.key,
    this.excludeTagIds = const {},
    required this.title,
    required this.subtitle,
  });

  /// Shows the dialog and returns the selected tag or null if cancelled.
  static Future<Tag?> show(
    BuildContext context, {
    Set<UuidValue> excludeTagIds = const {},
    required String title,
    required String subtitle,
  }) {
    return showDialog<Tag>(
      context: context,
      builder: (context) => TagPickerDialog(
        excludeTagIds: excludeTagIds,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<TagPickerDialog> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tag> _getFilteredTags(List<Tag> allTags) {
    final query = _searchController.text;

    var filtered = allTags
        .where((tag) => !widget.excludeTagIds.contains(tag.id))
        .toList();

    if (query.isEmpty) {
      return filtered;
    }

    final lowerQuery = query.toLowerCase();
    return filtered
        .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<TagCubit, TagState>(
          builder: (context, tagState) {
            final filteredTags = _getFilteredTags(tagState.tags);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search tags',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: filteredTags.isEmpty
                      ? const Center(
                          child: Text('No other tags available'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredTags.length,
                          itemBuilder: (context, index) {
                            final tag = filteredTags[index];

                            return ListTile(
                              leading: TagAvatar(tag: tag),
                              title: Text(tag.name),
                              subtitle: tag.isTransfer
                                  ? const Text('Transfer')
                                  : null,
                              onTap: () {
                                Navigator.of(context).pop(tag);
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
