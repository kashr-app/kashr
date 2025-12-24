import 'package:kashr/core/color_utils.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// Mode for the batch tag dialog.
enum BatchTagMode { add, remove }

/// Dialog for selecting a tag to add or remove from multiple turnovers.
class BatchTagDialog extends StatefulWidget {
  const BatchTagDialog({
    required this.availableTags,
    required this.mode,
    super.key,
  });

  final List<Tag> availableTags;
  final BatchTagMode mode;

  @override
  State<BatchTagDialog> createState() => _BatchTagDialogState();
}

class _BatchTagDialogState extends State<BatchTagDialog> {
  late TextEditingController _searchController;
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTags = widget.availableTags;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredTags = widget.availableTags;
      } else {
        _filteredTags = widget.availableTags
            .where((tag) => tag.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAddMode = widget.mode == BatchTagMode.add;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAddMode ? 'Select Tag to Add' : 'Select Tag to Remove',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Divider(),
            Flexible(
              child: _filteredTags.isEmpty
                  ? const Center(child: Text('No tags found'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        final tagColor =
                            ColorUtils.parseColor(tag.color) ?? Colors.grey;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tagColor.withValues(alpha: 0.3),
                            child: Icon(
                              isAddMode ? Icons.label : Icons.label_off,
                              color: tagColor,
                              size: 20,
                            ),
                          ),
                          title: Text(tag.name),
                          onTap: () {
                            Navigator.of(context).pop(tag);
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
