import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/body_composition_entry.dart';
import 'database_helper.dart';

class BodyCompositionService {
  static final BodyCompositionService instance = BodyCompositionService._internal();
  BodyCompositionService._internal();

  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<BodyCompositionEntry>> listEntries() async {
    final db = await _db;
    final maps = await db.query(
      'body_composition_entries',
      orderBy: 'measured_at ASC',
    );
    return maps.map((m) => BodyCompositionEntry.fromMap(m)).toList();
  }

  Future<BodyCompositionEntry> upsert(BodyCompositionEntry entry) async {
    final db = await _db;
    await db.insert(
      'body_composition_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return entry;
  }

  Future<BodyCompositionEntry> create({
    required DateTime measuredAt,
    required double weightKg,
    double? bodyFatPct,
    double? bodyFatKg,
    double? skeletalMuscleMassPct,
    double? skeletalMuscleMassKg,
    double? fatFreeMassKg,
    double? bodyWaterPct,
    double? visceralFat,
    double? boneMineralKg,
    double? proteinPct,
    String? id,
  }) {
    final day = DateTime(measuredAt.year, measuredAt.month, measuredAt.day);
    final entry = BodyCompositionEntry(
      id: id ?? _uuid.v4(),
      measuredAt: day,
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      bodyFatKg: bodyFatKg,
      skeletalMuscleMassPct: skeletalMuscleMassPct,
      skeletalMuscleMassKg: skeletalMuscleMassKg,
      fatFreeMassKg: fatFreeMassKg,
      bodyWaterPct: bodyWaterPct,
      visceralFat: visceralFat,
      boneMineralKg: boneMineralKg,
      proteinPct: proteinPct,
    );
    return upsert(entry);
  }

  Future<int> importEntries(List<BodyCompositionEntry> entries) async {
    var n = 0;
    for (final e in entries) {
      await upsert(e);
      n++;
    }
    return n;
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(
      'body_composition_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
