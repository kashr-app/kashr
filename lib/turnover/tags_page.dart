import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/widgets/tag_edit_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Tags')),
      body: SafeArea(
        child: BlocBuilder<TagCubit, TagState>(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showTagDialog(BuildContext context, {Tag? tag}) {
    TagEditBottomSheet.show(context, tag: tag);
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
    final color = ColorUtils.parseColor(tag.color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color ?? theme.colorScheme.primaryContainer,
        child: Text(
          tag.name.isNotEmpty ? tag.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: color != null
                ? ColorUtils.getContrastingTextColor(color)
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(tag.name),
      subtitle: tag.isTransfer ? const Text('Transfer') : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
