import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A dialog for selecting or creating a tag.
///
/// Allows searching existing tags or creating a new tag if no exact match
/// is found. Returns the selected/created [Tag] or null if cancelled.
class AddTagDialog extends StatefulWidget {
  const AddTagDialog({super.key});

  /// Shows the dialog and returns the selected/created tag or null if cancelled.
  static Future<Tag?> show(BuildContext context) {
    return showDialog<Tag>(
      context: context,
      builder: (context) => const AddTagDialog(),
    );
  }

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
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
    if (query.isEmpty) {
      return allTags;
    }
    final lowerQuery = query.toLowerCase();
    return allTags
        .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagCubit = context.read<TagCubit>();

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
                  'Select Tag',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search or create tag',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                if (searchQuery.isNotEmpty && !exactMatch)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.add),
                    ),
                    title: Text('Create "$searchQuery"'),
                    onTap: () async {
                      final newTag = Tag(
                        id: const Uuid().v4obj(),
                        name: searchQuery,
                      );
                      await tagCubit.createTag(newTag);
                      if (context.mounted) {
                        Navigator.of(context).pop(newTag);
                      }
                    },
                  ),
                const Divider(),
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
                              onTap: () {
                                Navigator.of(context).pop(tag);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
