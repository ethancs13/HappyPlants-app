import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<PlantRepository> _openRepo() async {
  final db = await databaseFactoryFfi.openDatabase(
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
            plant_key TEXT,
            schedule_on_calendar INTEGER NOT NULL DEFAULT 0,
            notifications_enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    ),
  );
  return PlantRepository.forTesting(db);
}

void main() {
  late PlantRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => repo = await _openRepo());
  tearDown(() async => repo.close());

  group('PlantRepository', () {
    test('insert returns new id', () async {
      final id = await repo.insert(
          Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      expect(id, greaterThan(0));
    });

    test('getAll returns empty list initially', () async {
      expect(await repo.getAll(), isEmpty);
    });

    test('getAll returns inserted plants', () async {
      await repo.insert(
          Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      await repo.insert(
          Plant(name: 'Cactus', species: 'Cactaceae', wateringIntervalDays: 14));
      expect((await repo.getAll()).length, 2);
    });

    test('getById returns correct plant', () async {
      final id = await repo.insert(
          Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      final plant = await repo.getById(id);
      expect(plant, isNotNull);
      expect(plant!.name, 'Monstera');
      expect(plant.id, id);
    });

    test('getById returns null for missing id', () async {
      expect(await repo.getById(999), isNull);
    });

    test('update persists changes', () async {
      final id = await repo.insert(
          Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      final original = await repo.getById(id);
      await repo.update(original!.copyWith(name: 'Mini Monstera'));
      expect((await repo.getById(id))!.name, 'Mini Monstera');
    });

    test('delete removes plant', () async {
      final id = await repo.insert(
          Plant(name: 'Monstera', species: 'M. deliciosa', wateringIntervalDays: 7));
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
    });

    test('plants ordered by name', () async {
      await repo.insert(
          Plant(name: 'Zebra Plant', species: 'Z. sp', wateringIntervalDays: 7));
      await repo.insert(
          Plant(name: 'Aloe', species: 'A. vera', wateringIntervalDays: 14));
      final plants = await repo.getAll();
      expect(plants.first.name, 'Aloe');
      expect(plants.last.name, 'Zebra Plant');
    });

    test('showScheduleOnCalendar defaults to false', () async {
      final id = await repo.insert(
          Plant(name: 'Fern', species: 'Nephrolepis', wateringIntervalDays: 3));
      final plant = await repo.getById(id);
      expect(plant!.showScheduleOnCalendar, isFalse);
    });

    test('notificationsEnabled defaults to true', () async {
      final id = await repo.insert(
          Plant(name: 'Fern', species: 'Nephrolepis', wateringIntervalDays: 3));
      final plant = await repo.getById(id);
      expect(plant!.notificationsEnabled, isTrue);
    });

    test('update persists showScheduleOnCalendar', () async {
      final id = await repo.insert(
          Plant(name: 'Fern', species: 'Nephrolepis', wateringIntervalDays: 3));
      final plant = await repo.getById(id);
      await repo.update(plant!.copyWith(showScheduleOnCalendar: true));
      expect((await repo.getById(id))!.showScheduleOnCalendar, isTrue);
    });

    test('update persists notificationsEnabled = false', () async {
      final id = await repo.insert(
          Plant(name: 'Fern', species: 'Nephrolepis', wateringIntervalDays: 3));
      final plant = await repo.getById(id);
      await repo.update(plant!.copyWith(notificationsEnabled: false));
      expect((await repo.getById(id))!.notificationsEnabled, isFalse);
    });

    test('update persists plant_key', () async {
      final id = await repo.insert(
          Plant(name: 'Cactus', species: 'Cactaceae', wateringIntervalDays: 14));
      final plant = await repo.getById(id);
      await repo.update(plant!.copyWith(plantKey: 'plant_03'));
      expect((await repo.getById(id))!.plantKey, 'plant_03');
    });

    test('update persists lastWateredDate', () async {
      final date = DateTime(2026, 4, 10);
      final id = await repo.insert(
          Plant(name: 'Aloe', species: 'A. vera', wateringIntervalDays: 7));
      final plant = await repo.getById(id);
      await repo.update(plant!.copyWith(lastWateredDate: date));
      final updated = await repo.getById(id);
      expect(updated!.lastWateredDate!.year, 2026);
      expect(updated.lastWateredDate!.month, 4);
      expect(updated.lastWateredDate!.day, 10);
    });
  });
}
