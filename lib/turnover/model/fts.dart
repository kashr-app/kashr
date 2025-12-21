/// Sanitizes a user input string for use with SQLite FTS5 MATCH queries.
///
/// This function escapes all user input as literal text, with the exception
/// of a single trailing `*` which enables prefix search (e.g., "foo*" matches
/// "food", "football", etc.).
///
/// All tokens are quoted to prevent FTS5 syntax interpretation. Internal
/// quotes are escaped by doubling them per FTS5 convention.
String sanitizeFts5Query(String query) {
  if (query.trim().isEmpty) return query;

  final tokens = <String>[];

  for (var token in query.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;

    // Check if token has a trailing asterisk (prefix search)
    final hasTrailingStar = token.endsWith('*');

    // Remove trailing asterisk for escaping
    final tokenWithoutStar = hasTrailingStar
        ? token.substring(0, token.length - 1)
        : token;

    if (tokenWithoutStar.isEmpty) continue;

    // Escape internal quotes by doubling them (FTS5 convention)
    final escaped = tokenWithoutStar.replaceAll('"', '""');

    // Quote the token, add trailing * outside quotes if needed
    tokens.add(hasTrailingStar ? '"$escaped"*' : '"$escaped"');
  }

  return tokens.join(' ');
}
