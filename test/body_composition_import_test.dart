import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/utils/body_composition_import.dart';

void main() {
  group('parseBodyCompositionPaste', () {
    test('parses header row and European dates', () {
      const raw = '''
Date	Weight	Body fat %	Body Fat kg
5.04.2026	82.15	23.80	19.55
4.04.2026	81.50	24.10	19.64
''';
      final rows = parseBodyCompositionPaste(raw);
      expect(rows.length, 2);
      expect(rows[0].weightKg, 82.15);
      expect(rows[0].bodyFatPct, 23.80);
      expect(rows[0].bodyFatKg, 19.55);
      expect(rows[0].measuredAt, DateTime(2026, 4, 5));
      expect(rows[1].measuredAt, DateTime(2026, 4, 4));
    });

    test('normalizes short year typo to 2026', () {
      const raw = '6.03.226\t82.20\t24.90';
      final rows = parseBodyCompositionPaste(raw);
      expect(rows.single.measuredAt, DateTime(2026, 3, 6));
    });

    test('throws on empty input', () {
      expect(
        () => parseBodyCompositionPaste('   \n  '),
        throwsA(isA<BodyCompositionImportParseException>()),
      );
    });
  });
}
