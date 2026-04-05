import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CareLogRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = CareLogRepository.forTesting(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE care_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plant_id INTEGER NOT NULL,
                type TEXT NOT NULL,
                date TEXT NOT NULL,
                notes TEXT
              )
            ''');
          },
        ),
      ),
    );
  });

  tearDown(() async => repo.close());

  final now = DateTime(2024, 6, 3);

  group('CareLogRepository', () {
    test('insert returns new id', () async {
      final log = CareLog(plantId: 1, type: CareType.watering, date: now);
      final id = await repo.insert(log);
      expect(id, greaterThan(0));
    });

    test('getByPlantId returns empty list initially', () async {
      final logs = await repo.getByPlantId(1);
      expect(logs, isEmpty);
    });

    test('getByPlantId returns logs for correct plant', () async {
      await repo.insert(CareLog(plantId: 1, type: CareType.watering, date: now));
      await repo.insert(CareLog(plantId: 1, type: CareType.fertilizing, date: now));
      await repo.insert(CareLog(plantId: 2, type: CareType.watering, date: now));

      final logs = await repo.getByPlantId(1);
      expect(logs.length, 2);
      expect(logs.every((l) => l.plantId == 1), isTrue);
    });

    test('getByPlantId returns logs newest first', () async {
      final older = DateTime(2024, 5, 1);
      final newer = DateTime(2024, 6, 1);
      await repo.insert(CareLog(plantId: 1, type: CareType.watering, date: older));
      await repo.insert(CareLog(plantId: 1, type: CareType.watering, date: newer));

      final logs = await repo.getByPlantId(1);
      expect(logs.first.date, newer);
      expect(logs.last.date, older);
    });

    test('delete removes log', () async {
      final id = await repo.insert(CareLog(plantId: 1, type: CareType.watering, date: now));
      await repo.delete(id);
      final logs = await repo.getByPlantId(1);
      expect(logs, isEmpty);
    });

    test('deleteByPlantId removes all logs for plant', () async {
      await repo.insert(CareLog(plantId: 1, type: CareType.watering, date: now));
      await repo.insert(CareLog(plantId: 1, type: CareType.fertilizing, date: now));
      await repo.insert(CareLog(plantId: 2, type: CareType.watering, date: now));

      await repo.deleteByPlantId(1);

      expect(await repo.getByPlantId(1), isEmpty);
      expect(await repo.getByPlantId(2), hasLength(1));
    });
  });
}
