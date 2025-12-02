extension MapFilter<K, V> on Map<K, V> {
  /// Returns a new map containing only entries that satisfy [test].
  Map<K, V> where(bool Function(K key, V value) test) {
    return {
      for (final entry in entries)
        if (test(entry.key, entry.value)) entry.key: entry.value,
    };
  }
}
