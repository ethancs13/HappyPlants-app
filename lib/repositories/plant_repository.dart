import 'package:sqflite/sqflite.dart';
import 'package:happy_plants/db/database_helper.dart';
import 'package:happy_plants/models/plant.dart';

class PlantRepository {
  final Database _db;

  PlantRepository._(this._db);

  /// Production constructor — uses the shared singleton database.
  static Future<PlantRepository> create() async {
    final db = await DatabaseHelper.instance.database;
    return PlantRepository._(db);
  }

  /// Testing constructor — accepts an in-memory database.
  PlantRepository.forTesting(this._db);

  Future<int> insert(Plant plant) =>
      _db.insert('plants', plant.toMap());

  Future<List<Plant>> getAll() async {
    final rows = await _db.query('plants', orderBy: 'name ASC');
    return rows.map(Plant.fromMap).toList();
  }

  Future<Plant?> getById(int id) async {
    final rows = await _db.query('plants', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Plant.fromMap(rows.first);
  }

  Future<void> update(Plant plant) =>
      _db.update('plants', plant.toMap(), where: 'id = ?', whereArgs: [plant.id]);

  Future<void> delete(int id) =>
      _db.delete('plants', where: 'id = ?', whereArgs: [id]);

  Future<void> close() => _db.close();
}
