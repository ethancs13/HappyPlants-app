import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<PlantPhotoRepository> _openRepo() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
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
  return PlantPhotoRepository.forTesting(db);
}

PlantPhoto _photo(int plantId, {String path = '/img/test.jpg', bool isCover = false, String? notes}) =>
    PlantPhoto(
      plantId: plantId,
      filePath: path,
      dateTaken: DateTime(2026, 4, 16),
      isCover: isCover,
      notes: notes,
    );

void main() {
  late PlantPhotoRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async => repo = await _openRepo());
  tearDown(() async => repo.close());

  group('PlantPhotoRepository', () {
    test('insert assigns an id', () async {
      final photo = await repo.insert(_photo(1));
      expect(photo.id, isNotNull);
      expect(photo.id, greaterThan(0));
    });

    test('getByPlantId returns empty list initially', () async {
      expect(await repo.getByPlantId(1), isEmpty);
    });

    test('getByPlantId returns only photos for that plant', () async {
      await repo.insert(_photo(1, path: '/a.jpg'));
      await repo.insert(_photo(1, path: '/b.jpg'));
      await repo.insert(_photo(2, path: '/c.jpg'));

      final photos = await repo.getByPlantId(1);
      expect(photos.length, 2);
      expect(photos.every((p) => p.plantId == 1), isTrue);
    });

    test('getByPlantId returns newest first', () async {
      final older = PlantPhoto(
          plantId: 1, filePath: '/old.jpg', dateTaken: DateTime(2026, 1, 1));
      final newer = PlantPhoto(
          plantId: 1, filePath: '/new.jpg', dateTaken: DateTime(2026, 4, 1));
      await repo.insert(older);
      await repo.insert(newer);

      final photos = await repo.getByPlantId(1);
      expect(photos.first.filePath, '/new.jpg');
    });

    test('getCoverPhoto returns null when none set', () async {
      await repo.insert(_photo(1));
      expect(await repo.getCoverPhoto(1), isNull);
    });

    test('getCoverPhoto returns the cover photo', () async {
      await repo.insert(_photo(1, path: '/a.jpg'));
      await repo.insert(_photo(1, path: '/b.jpg', isCover: true));

      final cover = await repo.getCoverPhoto(1);
      expect(cover, isNotNull);
      expect(cover!.filePath, '/b.jpg');
    });

    test('setCover updates cover to new photo', () async {
      final a = await repo.insert(_photo(1, path: '/a.jpg', isCover: true));
      final b = await repo.insert(_photo(1, path: '/b.jpg'));

      await repo.setCover(1, b.id!);

      expect((await repo.getCoverPhoto(1))!.filePath, '/b.jpg');
      // old cover cleared
      final allPhotos = await repo.getByPlantId(1);
      final oldCover = allPhotos.firstWhere((p) => p.id == a.id);
      expect(oldCover.isCover, isFalse);
    });

    test('setCover only affects photos for the given plant', () async {
      final p1 = await repo.insert(_photo(1, path: '/p1.jpg', isCover: true));
      await repo.insert(_photo(2, path: '/p2.jpg', isCover: true));
      final p1b = await repo.insert(_photo(1, path: '/p1b.jpg'));

      await repo.setCover(1, p1b.id!);

      // plant 2 cover untouched
      expect((await repo.getCoverPhoto(2))!.filePath, '/p2.jpg');
      // plant 1 cover changed
      expect((await repo.getCoverPhoto(1))!.filePath, '/p1b.jpg');
      expect(p1.id, isNotNull); // reference p1 to suppress unused warning
    });

    test('delete removes the photo', () async {
      final photo = await repo.insert(_photo(1));
      await repo.delete(photo.id!);
      expect(await repo.getByPlantId(1), isEmpty);
    });

    test('delete only removes the targeted photo', () async {
      final a = await repo.insert(_photo(1, path: '/a.jpg'));
      await repo.insert(_photo(1, path: '/b.jpg'));

      await repo.delete(a.id!);

      final remaining = await repo.getByPlantId(1);
      expect(remaining.length, 1);
      expect(remaining.first.filePath, '/b.jpg');
    });

    test('deleteByPlantId removes all photos for that plant', () async {
      await repo.insert(_photo(1, path: '/a.jpg'));
      await repo.insert(_photo(1, path: '/b.jpg'));
      await repo.insert(_photo(2, path: '/c.jpg'));

      await repo.deleteByPlantId(1);

      expect(await repo.getByPlantId(1), isEmpty);
      expect(await repo.getByPlantId(2), hasLength(1));
    });

    test('getCoverPhotoMap returns plantId to file path mapping', () async {
      await repo.insert(_photo(1, path: '/cover1.jpg', isCover: true));
      await repo.insert(_photo(1, path: '/extra.jpg'));
      await repo.insert(_photo(2, path: '/cover2.jpg', isCover: true));

      final map = await repo.getCoverPhotoMap();
      expect(map[1], '/cover1.jpg');
      expect(map[2], '/cover2.jpg');
    });

    test('getCoverPhotoMap excludes plants with no cover', () async {
      await repo.insert(_photo(1, path: '/a.jpg')); // no cover
      await repo.insert(_photo(2, path: '/b.jpg', isCover: true));

      final map = await repo.getCoverPhotoMap();
      expect(map.containsKey(1), isFalse);
      expect(map.containsKey(2), isTrue);
    });

    test('notes are persisted', () async {
      final photo = await repo.insert(_photo(1, notes: 'New leaf sprouting'));
      final fetched = (await repo.getByPlantId(1)).first;
      expect(fetched.id, photo.id);
      expect(fetched.notes, 'New leaf sprouting');
    });
  });
}
