import 'package:happy_plants/db/database_helper.dart';
import 'package:happy_plants/models/plant_photo.dart';

class PlantPhotoRepository {
  final _db = DatabaseHelper.instance;

  PlantPhotoRepository._();

  static Future<PlantPhotoRepository> create() async {
    final repo = PlantPhotoRepository._();
    await repo._db.database; // ensure DB is open
    return repo;
  }

  Future<PlantPhoto> insert(PlantPhoto photo) async {
    final db = await _db.database;
    final id = await db.insert('plant_photos', photo.toMap());
    return photo.copyWith(id: id);
  }

  Future<List<PlantPhoto>> getByPlantId(int plantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'plant_photos',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'date_taken DESC',
    );
    return rows.map(PlantPhoto.fromMap).toList();
  }

  Future<PlantPhoto?> getCoverPhoto(int plantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'plant_photos',
      where: 'plant_id = ? AND is_cover = 1',
      whereArgs: [plantId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PlantPhoto.fromMap(rows.first);
  }

  /// Clears is_cover on all photos for the plant, then sets it on [photoId].
  Future<void> setCover(int plantId, int photoId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'plant_photos',
        {'is_cover': 0},
        where: 'plant_id = ?',
        whereArgs: [plantId],
      );
      await txn.update(
        'plant_photos',
        {'is_cover': 1},
        where: 'id = ?',
        whereArgs: [photoId],
      );
    });
  }

  Future<void> delete(int photoId) async {
    final db = await _db.database;
    await db.delete('plant_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  /// Returns a map of plantId → cover file path for all plants that have one.
  Future<Map<int, String>> getCoverPhotoMap() async {
    final db = await _db.database;
    final rows = await db.query(
      'plant_photos',
      columns: ['plant_id', 'file_path'],
      where: 'is_cover = 1',
    );
    return {
      for (final row in rows)
        row['plant_id'] as int: row['file_path'] as String,
    };
  }

  Future<void> deleteByPlantId(int plantId) async {
    final db = await _db.database;
    await db.delete(
      'plant_photos',
      where: 'plant_id = ?',
      whereArgs: [plantId],
    );
  }
}
