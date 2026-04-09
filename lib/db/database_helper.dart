import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'happy_plants.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        color TEXT,
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE plant_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        date_taken TEXT NOT NULL,
        is_cover INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        is_context INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE gemini_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        parts TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE plants ADD COLUMN plant_key TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE plant_photos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plant_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          date_taken TEXT NOT NULL,
          is_cover INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE chat_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          text TEXT NOT NULL,
          is_user INTEGER NOT NULL,
          is_context INTEGER NOT NULL DEFAULT 0,
          timestamp TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE gemini_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          parts TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE care_logs ADD COLUMN emoji TEXT');
      await db.execute('ALTER TABLE care_logs ADD COLUMN color TEXT');
    }
    if (oldVersion < 6) {
      // Guard against installs where the column was added outside a clean migration path.
      final cols = await db.rawQuery('PRAGMA table_info(plants)');
      final hasCol = cols.any((c) => c['name'] == 'schedule_on_calendar');
      if (!hasCol) {
        await db.execute(
          'ALTER TABLE plants ADD COLUMN schedule_on_calendar INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE plants ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> close() async => _db?.close();
}
