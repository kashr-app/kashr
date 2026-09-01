import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/ingest/ingest_source.dart';

void main() {
  group('IngestSourceConverter', () {
    const converter = IngestSourceConverter();

    test('round trips every source', () {
      for (final source in IngestSource.values) {
        expect(converter.fromJson(converter.toJson(source)), source);
      }
    });

    test('falls back to asking on a value it does not know', () {
      expect(converter.fromJson('sepa'), IngestSource.ask);
    });
  });

  group('settable', () {
    test('offers asking and every source a tap can land on', () {
      expect(IngestSource.settable, [IngestSource.ask, IngestSource.bank]);
    });

    test('leaves out manual, which only points at other buttons', () {
      expect(IngestSource.settable, isNot(contains(IngestSource.manual)));
    });

    test('leaves out csv until it exists', () {
      expect(IngestSource.settable, isNot(contains(IngestSource.csv)));
    });
  });
}
