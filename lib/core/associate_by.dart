/// Associates a [list] by [key]
/// ```
/// final x = [{'id': 1}, {'id': 2}];
/// final y = x.associateBy(
///   (it) => int.parse(it['id']),
/// );
/// // y = {
/// //  1: {'id': 1},
/// //  2: {'id': 2}
/// // }
extension AssociateBy<T> on Iterable<T> {
  Map<K, T> associateBy<K, V>(
    K Function(T it) key,
  ) {
    return {
      for (var it in this) key(it): it,
    };
  }
}
