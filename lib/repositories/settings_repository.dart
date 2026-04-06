import 'package:sqflite/sqflite.dart';
import 'package:happy_plants/db/database_helper.dart';

class SettingsRepository {
  final Database _db;

  SettingsRepository._(this._db);

  static Future<SettingsRepository> create() async {
    final db = await DatabaseHelper.instance.database;
    return SettingsRepository._(db);
  }

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) => _db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
