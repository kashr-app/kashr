import 'package:finanalyzer/turnover/model/recent_search.dart';
import 'package:finanalyzer/turnover/model/recent_search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full-screen modal dialog for searching turnovers.
/// Shows recent searches and allows entering new search queries.
class TurnoverSearchDialog extends StatefulWidget {
  const TurnoverSearchDialog({super.key});

  @override
  State<TurnoverSearchDialog> createState() => _TurnoverSearchDialogState();
}

class _TurnoverSearchDialogState extends State<TurnoverSearchDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late final RecentSearchRepository _repository;
  List<RecentSearch> _recentSearches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RecentSearchRepository>();
    _loadRecentSearches();

    // Auto-focus the search field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    setState(() => _isLoading = true);
    try {
      final searches = await _repository.getRecentSearches();
      setState(() {
        _recentSearches = searches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _submitSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // Save to recent searches
    await _repository.addRecentSearch(trimmedQuery);

    // Return the search query to the caller
    if (mounted) {
      Navigator.of(context).pop(trimmedQuery);
    }
  }

  void _selectRecentSearch(RecentSearch search) {
    _submitSearch(search.query);
  }

  Future<void> _deleteRecentSearch(RecentSearch search) async {
    await _repository.removeRecentSearch(search.id);
    await _loadRecentSearches();
  }

  Future<void> _clearAllRecentSearches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all recent searches?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.clearAllRecentSearches();
      await _loadRecentSearches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search turnovers...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _submitSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              tooltip: 'Clear',
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent searches',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a search query above to find turnovers',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearAllRecentSearches,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return _RecentSearchItem(
                search: search,
                onTap: () => _selectRecentSearch(search),
                onDelete: () => _deleteRecentSearch(search),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentSearchItem extends StatelessWidget {
  const _RecentSearchItem({
    required this.search,
    required this.onTap,
    required this.onDelete,
  });

  final RecentSearch search;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history),
      title: Text(search.query),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDelete,
        tooltip: 'Remove',
      ),
      onTap: onTap,
    );
  }
}
