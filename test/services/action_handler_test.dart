/// Tests for every action a user (or the AI bot) can perform.
///
/// Each test exercises the exact repository operations that back a user action,
/// keeping things fast and deterministic with an in-memory SQLite database.
/// NotificationService is intentionally excluded — it requires Android platform
/// channels that are not available in the test environment.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── Shared helpers ─────────────────────────────────────────────────────────────

Future<Database> _openDb() => databaseFactoryFfi.openDatabase(
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
          await db.execute('''
            CREATE TABLE care_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              plant_id INTEGER NOT NULL,
              type TEXT NOT NULL,
              date TEXT NOT NULL,
              notes TEXT,
              emoji TEXT,
              color TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE plant_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              plant_id INTEGER NOT NULL,
              file_path TEXT NOT NULL,
              date_taken TEXT NOT NULL,
              is_cover INTEGER NOT NULL DEFAULT 0,
              notes TEXT
            )
          ''');
        },
      ),
    );

Plant _plant({
  String name = 'Monstera',
  String species = 'M. deliciosa',
  int intervalDays = 7,
  DateTime? lastWatered,
  String? plantKey,
  String? notes,
}) =>
    Plant(
      name: name,
      species: species,
      wateringIntervalDays: intervalDays,
      lastWateredDate: lastWatered,
      plantKey: plantKey,
      notes: notes,
    );

PlantPhoto _photo(int plantId, {String path = '/img/a.jpg', bool isCover = false}) =>
    PlantPhoto(
      plantId: plantId,
      filePath: path,
      dateTaken: DateTime(2026, 4, 16),
      isCover: isCover,
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Each group opens its own isolated in-memory DB.

  // ── add_plant ───────────────────────────────────────────────────────────────

  group('add_plant', () {
    late PlantRepository plants;
    setUp(() async => plants = PlantRepository.forTesting(await _openDb()));
    tearDown(() async => plants.close());

    test('inserts plant and returns a valid id', () async {
      final id = await plants.insert(_plant());
      expect(id, greaterThan(0));
    });

    test('persists name, species, and watering interval', () async {
      final id = await plants.insert(
          _plant(name: 'Cactus', species: 'Cactaceae', intervalDays: 14));
      final saved = await plants.getById(id);
      expect(saved!.name, 'Cactus');
      expect(saved.species, 'Cactaceae');
      expect(saved.wateringIntervalDays, 14);
    });

    test('persists optional notes', () async {
      final id = await plants.insert(_plant(notes: 'Loves indirect light'));
      expect((await plants.getById(id))!.notes, 'Loves indirect light');
    });

    test('persists optional plant_key', () async {
      final id = await plants.insert(_plant(plantKey: 'plant_14'));
      expect((await plants.getById(id))!.plantKey, 'plant_14');
    });

    test('defaults showScheduleOnCalendar to false', () async {
      final id = await plants.insert(_plant());
      expect((await plants.getById(id))!.showScheduleOnCalendar, isFalse);
    });

    test('defaults notificationsEnabled to true', () async {
      final id = await plants.insert(_plant());
      expect((await plants.getById(id))!.notificationsEnabled, isTrue);
    });

    test('multiple plants are all retrievable', () async {
      await plants.insert(_plant(name: 'Aloe'));
      await plants.insert(_plant(name: 'Fern'));
      await plants.insert(_plant(name: 'Cactus'));
      expect((await plants.getAll()).length, 3);
    });
  });

  // ── update_plant ────────────────────────────────────────────────────────────

  group('update_plant', () {
    late PlantRepository plants;
    late int plantId;

    setUp(() async {
      plants = PlantRepository.forTesting(await _openDb());
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    Future<Plant> get() async => (await plants.getById(plantId))!;

    test('updates name', () async {
      await plants.update((await get()).copyWith(name: 'Mini Monstera'));
      expect((await get()).name, 'Mini Monstera');
    });

    test('updates species', () async {
      await plants.update((await get()).copyWith(species: 'M. adansonii'));
      expect((await get()).species, 'M. adansonii');
    });

    test('updates watering interval', () async {
      await plants.update((await get()).copyWith(wateringIntervalDays: 10));
      expect((await get()).wateringIntervalDays, 10);
    });

    test('updates notes', () async {
      await plants.update((await get()).copyWith(notes: 'Repot in spring'));
      expect((await get()).notes, 'Repot in spring');
    });

    test('updates plant_key', () async {
      await plants.update((await get()).copyWith(plantKey: 'plant_03'));
      expect((await get()).plantKey, 'plant_03');
    });

    test('other plants are not affected', () async {
      final otherId = await plants.insert(_plant(name: 'Aloe'));
      await plants.update((await get()).copyWith(name: 'Changed'));
      expect((await plants.getById(otherId))!.name, 'Aloe');
    });
  });

  // ── delete_plant ────────────────────────────────────────────────────────────

  group('delete_plant', () {
    late Database db;
    late PlantRepository plants;
    late CareLogRepository logs;
    late PlantPhotoRepository photos;
    late int plantId;

    setUp(() async {
      db = await _openDb();
      plants = PlantRepository.forTesting(db);
      logs = CareLogRepository.forTesting(db);
      photos = PlantPhotoRepository.forTesting(db);
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    test('removes the plant record', () async {
      await plants.delete(plantId);
      expect(await plants.getById(plantId), isNull);
    });

    test('removes associated care logs', () async {
      await logs.insert(
          CareLog(plantId: plantId, type: CareType.watering, date: DateTime.now()));
      await logs.deleteByPlantId(plantId);
      await plants.delete(plantId);
      expect(await logs.getByPlantId(plantId), isEmpty);
    });

    test('removes associated photos', () async {
      await photos.insert(_photo(plantId));
      await photos.deleteByPlantId(plantId);
      await plants.delete(plantId);
      expect(await photos.getByPlantId(plantId), isEmpty);
    });

    test('does not affect other plants', () async {
      final otherId = await plants.insert(_plant(name: 'Aloe'));
      await plants.delete(plantId);
      expect(await plants.getById(otherId), isNotNull);
    });
  });

  // ── log_care: watering ──────────────────────────────────────────────────────

  group('log_care (watering)', () {
    late Database db;
    late PlantRepository plants;
    late CareLogRepository logs;
    late int plantId;

    setUp(() async {
      db = await _openDb();
      plants = PlantRepository.forTesting(db);
      logs = CareLogRepository.forTesting(db);
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    test('inserts a watering log', () async {
      await logs.insert(
          CareLog(plantId: plantId, type: CareType.watering, date: DateTime.now()));
      final all = await logs.getByPlantId(plantId);
      expect(all.length, 1);
      expect(all.first.type, CareType.watering);
    });

    test('updates lastWateredDate on the plant', () async {
      final now = DateTime(2026, 4, 16);
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(lastWateredDate: now));
      final updated = (await plants.getById(plantId))!;
      expect(updated.lastWateredDate!.day, 16);
      expect(updated.lastWateredDate!.month, 4);
    });

    test('nextWateringDate advances by the interval', () async {
      final now = DateTime(2026, 4, 16);
      final plant = (await plants.getById(plantId))!; // interval = 7
      await plants.update(plant.copyWith(lastWateredDate: now));
      final updated = (await plants.getById(plantId))!;
      expect(updated.nextWateringDate, DateTime(2026, 4, 23));
    });

    test('multiple watering logs accumulate', () async {
      final d1 = DateTime(2026, 4, 10);
      final d2 = DateTime(2026, 4, 16);
      await logs.insert(CareLog(plantId: plantId, type: CareType.watering, date: d1));
      await logs.insert(CareLog(plantId: plantId, type: CareType.watering, date: d2));
      expect((await logs.getByPlantId(plantId)).length, 2);
    });
  });

  // ── log_care: fertilizing ───────────────────────────────────────────────────

  group('log_care (fertilizing)', () {
    late Database db;
    late PlantRepository plants;
    late CareLogRepository logs;
    late int plantId;

    setUp(() async {
      db = await _openDb();
      plants = PlantRepository.forTesting(db);
      logs = CareLogRepository.forTesting(db);
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    test('inserts a fertilizing log', () async {
      await logs.insert(
          CareLog(plantId: plantId, type: CareType.fertilizing, date: DateTime.now()));
      final all = await logs.getByPlantId(plantId);
      expect(all.first.type, CareType.fertilizing);
    });

    test('updates lastFertilizedDate on the plant', () async {
      final date = DateTime(2026, 4, 16);
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(lastFertilizedDate: date));
      final updated = (await plants.getById(plantId))!;
      expect(updated.lastFertilizedDate!.day, 16);
    });

    test('fertilizing log does not change lastWateredDate', () async {
      final date = DateTime(2026, 4, 16);
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(lastFertilizedDate: date));
      expect((await plants.getById(plantId))!.lastWateredDate, isNull);
    });
  });

  // ── set_next_watering ───────────────────────────────────────────────────────

  group('set_next_watering', () {
    late PlantRepository plants;
    late int plantId;

    setUp(() async {
      plants = PlantRepository.forTesting(await _openDb());
      plantId = await plants.insert(_plant(intervalDays: 7));
    });
    tearDown(() async => plants.close());

    test('anchor = nextDate - interval puts nextWateringDate on target day', () async {
      final target = DateTime(2026, 4, 23);
      final plant = (await plants.getById(plantId))!;
      final anchor = target.subtract(Duration(days: plant.wateringIntervalDays));
      await plants.update(plant.copyWith(lastWateredDate: anchor));
      expect((await plants.getById(plantId))!.nextWateringDate, target);
    });

    test('works when no prior lastWateredDate exists', () async {
      final target = DateTime(2026, 5, 1);
      final plant = (await plants.getById(plantId))!;
      expect(plant.lastWateredDate, isNull);
      final anchor = target.subtract(Duration(days: plant.wateringIntervalDays));
      await plants.update(plant.copyWith(lastWateredDate: anchor));
      expect((await plants.getById(plantId))!.nextWateringDate, target);
    });

    test('shifting the date actually changes the stored anchor', () async {
      final plant = (await plants.getById(plantId))!;
      final firstTarget = DateTime(2026, 4, 20);
      final secondTarget = DateTime(2026, 4, 25);

      await plants.update(plant.copyWith(
          lastWateredDate:
              firstTarget.subtract(Duration(days: plant.wateringIntervalDays))));
      expect((await plants.getById(plantId))!.nextWateringDate, firstTarget);

      final updated = (await plants.getById(plantId))!;
      await plants.update(updated.copyWith(
          lastWateredDate:
              secondTarget.subtract(Duration(days: updated.wateringIntervalDays))));
      expect((await plants.getById(plantId))!.nextWateringDate, secondTarget);
    });
  });

  // ── toggle_calendar_schedule ────────────────────────────────────────────────

  group('toggle_calendar_schedule', () {
    late PlantRepository plants;
    late int plantId;

    setUp(() async {
      plants = PlantRepository.forTesting(await _openDb());
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    test('enabling sets showScheduleOnCalendar to true', () async {
      final plant = (await plants.getById(plantId))!;
      expect(plant.showScheduleOnCalendar, isFalse);
      await plants.update(plant.copyWith(showScheduleOnCalendar: true));
      expect((await plants.getById(plantId))!.showScheduleOnCalendar, isTrue);
    });

    test('disabling sets showScheduleOnCalendar back to false', () async {
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(showScheduleOnCalendar: true));
      final enabled = (await plants.getById(plantId))!;
      await plants.update(enabled.copyWith(showScheduleOnCalendar: false));
      expect((await plants.getById(plantId))!.showScheduleOnCalendar, isFalse);
    });

    test('toggling one plant does not affect another', () async {
      final otherId = await plants.insert(_plant(name: 'Aloe'));
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(showScheduleOnCalendar: true));
      expect((await plants.getById(otherId))!.showScheduleOnCalendar, isFalse);
    });
  });

  // ── toggle_notifications ────────────────────────────────────────────────────

  group('toggle_notifications', () {
    late PlantRepository plants;
    late int plantId;

    setUp(() async {
      plants = PlantRepository.forTesting(await _openDb());
      plantId = await plants.insert(_plant());
    });
    tearDown(() async => plants.close());

    test('disabling sets notificationsEnabled to false', () async {
      final plant = (await plants.getById(plantId))!;
      expect(plant.notificationsEnabled, isTrue);
      await plants.update(plant.copyWith(notificationsEnabled: false));
      expect((await plants.getById(plantId))!.notificationsEnabled, isFalse);
    });

    test('re-enabling sets notificationsEnabled back to true', () async {
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(notificationsEnabled: false));
      final disabled = (await plants.getById(plantId))!;
      await plants.update(disabled.copyWith(notificationsEnabled: true));
      expect((await plants.getById(plantId))!.notificationsEnabled, isTrue);
    });

    test('toggling one plant does not affect another', () async {
      final otherId = await plants.insert(_plant(name: 'Aloe'));
      final plant = (await plants.getById(plantId))!;
      await plants.update(plant.copyWith(notificationsEnabled: false));
      expect((await plants.getById(otherId))!.notificationsEnabled, isTrue);
    });
  });

  // ── delete_photo ────────────────────────────────────────────────────────────

  group('delete_photo', () {
    late PlantPhotoRepository photos;
    late int plantId;

    setUp(() async {
      final db = await _openDb();
      photos = PlantPhotoRepository.forTesting(db);
      plantId = 1;
    });
    tearDown(() async => photos.close());

    test('removes the targeted photo', () async {
      final photo = await photos.insert(_photo(plantId));
      await photos.delete(photo.id!);
      expect(await photos.getByPlantId(plantId), isEmpty);
    });

    test('does not remove other photos for the same plant', () async {
      final a = await photos.insert(_photo(plantId, path: '/a.jpg'));
      await photos.insert(_photo(plantId, path: '/b.jpg'));
      await photos.delete(a.id!);

      final remaining = await photos.getByPlantId(plantId);
      expect(remaining.length, 1);
      expect(remaining.first.filePath, '/b.jpg');
    });

    test('does not affect photos for other plants', () async {
      final a = await photos.insert(_photo(1, path: '/a.jpg'));
      await photos.insert(_photo(2, path: '/b.jpg'));
      await photos.delete(a.id!);

      expect(await photos.getByPlantId(2), hasLength(1));
    });

    test('deleting the cover photo clears it from getCoverPhoto', () async {
      final cover = await photos.insert(_photo(plantId, isCover: true));
      await photos.delete(cover.id!);
      expect(await photos.getCoverPhoto(plantId), isNull);
    });
  });

  // ── set_cover_photo ─────────────────────────────────────────────────────────

  group('set_cover_photo', () {
    late PlantPhotoRepository photos;
    late int plantId;

    setUp(() async {
      final db = await _openDb();
      photos = PlantPhotoRepository.forTesting(db);
      plantId = 1;
    });
    tearDown(() async => photos.close());

    test('sets given photo as cover', () async {
      await photos.insert(_photo(plantId, path: '/a.jpg', isCover: true));
      final b = await photos.insert(_photo(plantId, path: '/b.jpg'));

      await photos.setCover(plantId, b.id!);

      expect((await photos.getCoverPhoto(plantId))!.filePath, '/b.jpg');
    });

    test('clears previous cover when setting a new one', () async {
      final a = await photos.insert(_photo(plantId, path: '/a.jpg', isCover: true));
      final b = await photos.insert(_photo(plantId, path: '/b.jpg'));

      await photos.setCover(plantId, b.id!);

      final allPhotos = await photos.getByPlantId(plantId);
      final oldCover = allPhotos.firstWhere((p) => p.id == a.id);
      expect(oldCover.isCover, isFalse);
    });

    test('does not change cover of another plant', () async {
      final p2Cover = await photos.insert(_photo(2, path: '/p2.jpg', isCover: true));
      await photos.insert(_photo(plantId, path: '/a.jpg', isCover: true));
      final b = await photos.insert(_photo(plantId, path: '/b.jpg'));

      await photos.setCover(plantId, b.id!);

      // plant 2's cover is unchanged
      expect((await photos.getCoverPhoto(2))!.id, p2Cover.id);
    });
  });

  // ── add_photo ───────────────────────────────────────────────────────────────

  group('add_photo', () {
    late PlantPhotoRepository photos;
    late int plantId;

    setUp(() async {
      final db = await _openDb();
      photos = PlantPhotoRepository.forTesting(db);
      plantId = 1;
    });
    tearDown(() async => photos.close());

    test('inserts photo and returns assigned id', () async {
      final photo = await photos.insert(_photo(plantId));
      expect(photo.id, isNotNull);
      expect(photo.id, greaterThan(0));
    });

    test('first photo is auto-set as cover', () async {
      final existing = await photos.getByPlantId(plantId);
      final isFirst = existing.isEmpty;
      final photo = await photos.insert(
          _photo(plantId, isCover: isFirst)); // matches chat_screen logic
      expect(photo.isCover, isTrue);
    });

    test('second photo is not auto-set as cover', () async {
      await photos.insert(_photo(plantId, isCover: true)); // first
      final second = await photos.insert(_photo(plantId, path: '/b.jpg', isCover: false));
      expect(second.isCover, isFalse);
      // original cover still in place
      expect((await photos.getCoverPhoto(plantId))!.filePath, '/img/a.jpg');
    });

    test('set_as_cover flag promotes second photo to cover', () async {
      await photos.insert(_photo(plantId, isCover: true));
      final second = await photos.insert(_photo(plantId, path: '/b.jpg'));
      await photos.setCover(plantId, second.id!);

      expect((await photos.getCoverPhoto(plantId))!.filePath, '/b.jpg');
    });

    test('photo notes are stored', () async {
      final photo = PlantPhoto(
        plantId: plantId,
        filePath: '/img/a.jpg',
        dateTaken: DateTime(2026, 4, 16),
        notes: 'Looking healthy today',
      );
      await photos.insert(photo);
      final saved = (await photos.getByPlantId(plantId)).first;
      expect(saved.notes, 'Looking healthy today');
    });
  });
}
