import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:kashr/turnover/widgets/tag_edit_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A dialog for selecting or creating a tag.
///
/// Allows searching existing tags with optional filtering, and optionally
/// creating new tags if no exact match is found.
/// Returns the selected/created [Tag] or null if cancelled.
class TagPickerDialog extends StatefulWidget {
  final bool Function(Tag)? filter;
  final String? title;
  final String? subtitle;
  final bool allowCreate;
  final TagSemantic? defaultSemantic;

  const TagPickerDialog({
    super.key,
    this.filter,
    this.title,
    this.subtitle,
    this.allowCreate = true,
    this.defaultSemantic,
  });

  /// Shows the dialog and returns the selected/created tag or null if cancelled.
  ///
  /// If [filter] is provided, only tags matching the filter will be shown.
  /// If [allowCreate] is true, users can create new tags.
  /// If [defaultSemantic] is provided, new tags will be created with that semantic.
  static Future<Tag?> show(
    BuildContext context, {
    bool Function(Tag tag)? filter,
    String? title,
    String? subtitle,
    bool allowCreate = true,
    TagSemantic? defaultSemantic,
  }) {
    return showDialog<Tag>(
      context: context,
      builder: (context) => TagPickerDialog(
        filter: filter,
        title: title,
        subtitle: subtitle,
        allowCreate: allowCreate,
        defaultSemantic: defaultSemantic,
      ),
    );
  }

  /// Shows the dialog with tag ID exclusions.
  ///
  /// Convenience method that converts [excludeTagIds] to a filter function.
  static Future<Tag?> showWithExclusions(
    BuildContext context, {
    Set<UuidValue> excludeTagIds = const {},
    String title = 'Select Tag',
    String? subtitle,
    bool allowCreate = false,
    TagSemantic? defaultSemantic,
  }) {
    return show(
      context,
      filter: excludeTagIds.isEmpty
          ? null
          : (tag) => !excludeTagIds.contains(tag.id),
      title: title,
      subtitle: subtitle,
      allowCreate: allowCreate,
      defaultSemantic: defaultSemantic,
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
    var filtered = allTags;

    // Apply custom filter if specified
    if (widget.filter != null) {
      filtered = filtered.where(widget.filter!).toList();
    }

    // Filter by search query
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      filtered = filtered
          .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    return filtered;
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
            final searchQuery = _searchController.text.trim();
            final exactMatch = filteredTags.any(
              (tag) => tag.name.toLowerCase() == searchQuery.toLowerCase(),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title ?? 'Select Tag',
                  style: theme.textTheme.titleLarge,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: widget.allowCreate
                        ? 'Search or create tag'
                        : 'Search tags',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (widget.allowCreate &&
                    searchQuery.isNotEmpty &&
                    !exactMatch) ...[
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text('Create "$searchQuery"'),
                    onTap: () async {
                      final newTag = await TagEditBottomSheet.show(
                        context,
                        initialName: searchQuery,
                        initialSemantic: widget.defaultSemantic,
                      );
                      if (context.mounted && newTag != null) {
                        Navigator.of(context).pop(newTag);
                      }
                    },
                  ),
                  const Divider(),
                ],
                Flexible(
                  child: filteredTags.isEmpty
                      ? const Center(child: Text('No tags found'))
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
