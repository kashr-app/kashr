extension MapFilter<K, V> on Map<K, V> {
  /// Returns a new map containing only entries that satisfy [test].
  Map<K, V> where(bool Function(K key, V value) test) {
    return {
      for (final entry in entries)
        if (test(entry.key, entry.value)) entry.key: entry.value,
    };
  }

  Map<K, V> sortedByValue(Comparable Function(V v) value, {bool isAsc = true}) {
    final entries = this.entries.toList();
    isAsc
        ? entries.sort((a, b) => value(a.value).compareTo(value(b.value)))
        : entries.sort((a, b) => value(b.value).compareTo(value(a.value)));
    return Map.fromEntries(entries);
  }
}
