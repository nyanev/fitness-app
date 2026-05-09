import 'package:uuid/uuid.dart';

import '../models/body_composition_entry.dart';

class BodyCompositionImportParseException implements Exception {
  final String message;
  BodyCompositionImportParseException(this.message);

  @override
  String toString() => message;
}

/// Parses tab- or multi-space–separated rows exported from a spreadsheet.
/// Date format: `d.M.yyyy` or `dd.MM.yyyy` (European).
List<BodyCompositionEntry> parseBodyCompositionPaste(String raw) {
  const uuid = Uuid();
  final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) {
    throw BodyCompositionImportParseException('No lines to import.');
  }

  var start = 0;
  if (_looksLikeHeader(lines.first)) {
    start = 1;
  }

  final out = <BodyCompositionEntry>[];
  for (var i = start; i < lines.length; i++) {
    final row = _splitRow(lines[i]);
    if (row.isEmpty || row.first.isEmpty || row.length < 2 || row[1].isEmpty) {
      throw BodyCompositionImportParseException('Line ${i + 1}: not enough columns.');
    }
    final date = _parseDate(row[0]);
    if (date == null) {
      throw BodyCompositionImportParseException('Line ${i + 1}: invalid date "${row[0]}".');
    }
    final weight = _parseDouble(row[1]);
    if (weight == null) {
      throw BodyCompositionImportParseException('Line ${i + 1}: invalid weight "${row[1]}".');
    }

    double? col(int index) {
      if (index >= row.length) return null;
      final s = row[index];
      if (s.isEmpty) return null;
      return _parseDouble(s);
    }

    out.add(
      BodyCompositionEntry(
        id: uuid.v4(),
        measuredAt: date,
        weightKg: weight,
        bodyFatPct: col(2),
        bodyFatKg: col(3),
        skeletalMuscleMassPct: col(4),
        skeletalMuscleMassKg: col(5),
        fatFreeMassKg: col(6),
        bodyWaterPct: col(7),
        visceralFat: col(8),
        boneMineralKg: col(9),
        proteinPct: col(10),
      ),
    );
  }

  if (out.isEmpty) {
    throw BodyCompositionImportParseException('No data rows found.');
  }
  return out;
}

bool _looksLikeHeader(String line) {
  final lower = line.toLowerCase();
  return lower.contains('date') &&
      (lower.contains('weight') || lower.contains('body'));
}

List<String> _splitRow(String line) {
  if (line.contains('\t')) {
    return line.split('\t').map((c) => c.trim()).toList();
  }
  return line
      .split(RegExp(r'\s{2,}'))
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
}

DateTime? _parseDate(String raw) {
  final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{2,4})$').firstMatch(raw.trim());
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  final month = int.tryParse(m.group(2)!);
  var year = int.tryParse(m.group(3)!);
  if (day == null || month == null || year == null) return null;
  if (year < 100) year += 2000;
  if (year >= 100 && year < 1000) {
    year = 2000 + (year % 100);
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

double? _parseDouble(String raw) {
  final s = raw.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}
