import 'package:sqflite/sqflite.dart';
import 'package:happy_plants/db/database_helper.dart';
import 'package:happy_plants/models/care_log.dart';

class CareLogRepository {
  final Database _db;

  CareLogRepository._(this._db);

  static Future<CareLogRepository> create() async {
    final db = await DatabaseHelper.instance.database;
    return CareLogRepository._(db);
  }

  CareLogRepository.forTesting(this._db);

  Future<int> insert(CareLog log) =>
      _db.insert('care_logs', log.toMap());

  Future<List<CareLog>> getByPlantId(int plantId) async {
    final rows = await _db.query(
      'care_logs',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'date DESC',
    );
    return rows.map(CareLog.fromMap).toList();
  }

  Future<void> delete(int id) =>
      _db.delete('care_logs', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteByPlantId(int plantId) =>
      _db.delete('care_logs', where: 'plant_id = ?', whereArgs: [plantId]);

  Future<void> close() => _db.close();
}
