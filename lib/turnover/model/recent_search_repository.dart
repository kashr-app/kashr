import 'package:kashr/db/db_helper.dart';
import 'package:kashr/turnover/model/recent_search.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing recent search queries
class RecentSearchRepository {
  static const int _maxRecentSearches = 200;

  /// Get recent search queries, ordered by most recent first
  Future<List<RecentSearch>> getRecentSearches({
    int limit = _maxRecentSearches,
  }) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'recent_search',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => RecentSearch.fromJson(map)).toList();
  }

  /// Add a new search query to recent searches
  /// If the query already exists, update its created_at timestamp
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    final db = await DatabaseHelper().database;
    final trimmedQuery = query.trim();

    // Check if query already exists
    final existing = await db.query(
      'recent_search',
      where: 'query = ?',
      whereArgs: [trimmedQuery],
    );

    if (existing.isNotEmpty) {
      // Update timestamp if query exists
      await db.update(
        'recent_search',
        {'created_at': DateTime.now().toIso8601String()},
        where: 'query = ?',
        whereArgs: [trimmedQuery],
      );
    } else {
      // Insert new search query
      final recentSearch = RecentSearch(
        id: const Uuid().v4obj(),
        query: trimmedQuery,
        createdAt: DateTime.now(),
      );
      await db.insert('recent_search', recentSearch.toJson());

      // Keep only the most recent searches
      await _cleanupOldSearches();
    }
  }

  /// Remove a specific search query
  Future<void> removeRecentSearch(UuidValue id) async {
    final db = await DatabaseHelper().database;
    await db.delete('recent_search', where: 'id = ?', whereArgs: [id.uuid]);
  }

  /// Clear all recent searches
  Future<void> clearAllRecentSearches() async {
    final db = await DatabaseHelper().database;
    await db.delete('recent_search');
  }

  /// Remove old searches beyond the maximum limit
  Future<void> _cleanupOldSearches() async {
    final db = await DatabaseHelper().database;

    // Get count of searches
    final count = await db.rawQuery(
      'SELECT COUNT(*) as count FROM recent_search',
    );
    final totalCount = count.first['count'] as int;

    if (totalCount > _maxRecentSearches) {
      // Delete oldest searches
      await db.delete(
        'recent_search',
        where: '''
          id IN (
            SELECT id FROM recent_search
            ORDER BY created_at DESC
            LIMIT -1 OFFSET ?
          )
          ''',
        whereArgs: [_maxRecentSearches],
      );
    }
  }
}
