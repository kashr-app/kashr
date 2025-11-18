import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class TagsRoute extends GoRouteData with $TagsRoute {
  const TagsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const TagsPage();
  }
}

/// Page for viewing, creating, and editing tags.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  @override
  void initState() {
    super.initState();
    context.read<TagCubit>().loadTags();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: BlocBuilder<TagCubit, TagState>(
        builder: (context, state) {
          if (state.status.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status.isError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.errorMessage ?? 'An error occurred',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.read<TagCubit>().loadTags(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state.tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No tags yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showTagDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Tag'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: state.tags.length,
            itemBuilder: (context, index) {
              final tag = state.tags[index];
              return _TagListItem(
                tag: tag,
                onTap: () => _showTagDialog(context, tag: tag),
                onDelete: () => _confirmDelete(context, tag),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTagDialog(BuildContext context, {Tag? tag}) {
    showDialog(
      context: context,
      builder: (dialogContext) => _TagEditDialog(tag: tag),
    );
  }

  void _confirmDelete(BuildContext context, Tag tag) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Are you sure you want to delete "${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<TagCubit>().deleteTag(tag.id!);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TagListItem extends StatelessWidget {
  final Tag tag;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TagListItem({
    required this.tag,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tag.color != null ? _parseColor(tag.color!) : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color ?? theme.colorScheme.primaryContainer,
        child: Text(
          tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color != null
                ? _getContrastingTextColor(color)
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(tag.name),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }

  Color? _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return null;
    }
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _TagEditDialog extends StatefulWidget {
  final Tag? tag;

  const _TagEditDialog({this.tag});

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late TextEditingController _nameController;
  Color? _selectedColor;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _selectedColor = widget.tag?.color != null
        ? _parseColor(widget.tag!.color!)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color? _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return null;
    }
  }

  String _colorToString(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Tag' : 'Create Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableColors.map((color) {
              final isSelected = _selectedColor == color;
              return InkWell(
                onTap: () => setState(() => _selectedColor = color),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          )
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: _getContrastingTextColor(color),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  final name = _nameController.text.trim();
                  final colorString =
                      _selectedColor != null ? _colorToString(_selectedColor!) : null;

                  final tag = Tag(
                    id: widget.tag?.id ?? const Uuid().v4obj(),
                    name: name,
                    color: colorString,
                  );

                  if (isEditing) {
                    context.read<TagCubit>().updateTag(tag);
                  } else {
                    context.read<TagCubit>().createTag(tag);
                  }

                  Navigator.of(context).pop();
                },
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
