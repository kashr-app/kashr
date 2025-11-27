import 'package:decimal/decimal.dart';

extension IterableToDecimalExt<T> on Iterable<T> {
  Decimal sum(Decimal Function(T e) toElement) =>
      map(toElement).fold(Decimal.zero, (sum, amount) => sum + amount);
}
