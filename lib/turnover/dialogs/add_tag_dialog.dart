import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';

/// A dialog for adding a tag to a turnover.
///
/// Allows searching existing tags or creating a new tag if no exact match
/// is found.
class AddTagDialog extends StatefulWidget {
  final TurnoverTagsCubit cubit;

  const AddTagDialog({required this.cubit, super.key});

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  late TextEditingController _searchController;
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTags = widget.cubit.state.availableTags;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredTags = widget.cubit.searchTags(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchQuery = _searchController.text.trim();
    final exactMatch = _filteredTags.any(
      (tag) => tag.name.toLowerCase() == searchQuery.toLowerCase(),
    );

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Tag',
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
            ),
            const SizedBox(height: 16),
            if (searchQuery.isNotEmpty && !exactMatch)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.add),
                ),
                title: Text('Create "$searchQuery"'),
                onTap: () async {
                  final newTag = await widget.cubit.createAndAddTag(
                    searchQuery,
                    null,
                  );
                  if (newTag != null && context.mounted) {
                    widget.cubit.addTag(newTag);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
            const Divider(),
            Flexible(
              child: _filteredTags.isEmpty
                  ? const Center(child: Text('No tags found'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];

                        return ListTile(
                          leading: TagAvatar(tag: tag),
                          title: Text(tag.name),
                          onTap: () {
                            widget.cubit.addTag(tag);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
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
