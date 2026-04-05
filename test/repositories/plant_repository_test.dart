import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late PlantRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = PlantRepository.forTesting(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE plants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                species TEXT NOT NULL,
                watering_interval_days INTEGER NOT NULL,
                last_watered_date TEXT,
                last_fertilized_date TEXT,
                notes TEXT,
                image_path TEXT
              )
            ''');
          },
        ),
      ),
    );
  });

  tearDown(() async => repo.close());

  group('PlantRepository', () {
    test('insert returns new id', () async {
      final plant = Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7);
      final id = await repo.insert(plant);
      expect(id, greaterThan(0));
    });

    test('getAll returns empty list initially', () async {
      final plants = await repo.getAll();
      expect(plants, isEmpty);
    });

    test('getAll returns inserted plants', () async {
      await repo.insert(Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      await repo.insert(Plant(name: 'Cactus', species: 'Cactaceae', wateringIntervalDays: 14));
      final plants = await repo.getAll();
      expect(plants.length, 2);
    });

    test('getById returns correct plant', () async {
      final id = await repo.insert(Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      final plant = await repo.getById(id);
      expect(plant, isNotNull);
      expect(plant!.name, 'Monstera');
      expect(plant.id, id);
    });

    test('getById returns null for missing id', () async {
      final plant = await repo.getById(999);
      expect(plant, isNull);
    });

    test('update persists changes', () async {
      final id = await repo.insert(Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      final original = await repo.getById(id);
      await repo.update(original!.copyWith(name: 'Mini Monstera'));
      final updated = await repo.getById(id);
      expect(updated!.name, 'Mini Monstera');
    });

    test('delete removes plant', () async {
      final id = await repo.insert(Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      await repo.delete(id);
      final plant = await repo.getById(id);
      expect(plant, isNull);
    });

    test('plants ordered by name', () async {
      await repo.insert(Plant(name: 'Zebra Plant', species: 'Z. sp', wateringIntervalDays: 7));
      await repo.insert(Plant(name: 'Aloe', species: 'A. vera', wateringIntervalDays: 14));
      final plants = await repo.getAll();
      expect(plants.first.name, 'Aloe');
      expect(plants.last.name, 'Zebra Plant');
    });
  });
}
