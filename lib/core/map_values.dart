extension MapValues<K, V> on Map<K, V> {
  Map<K, V2> mapValues<V2>(V2 Function(K key, V value) toElement) {
    return {for (final it in entries) it.key: toElement(it.key, it.value)};
  }
}
