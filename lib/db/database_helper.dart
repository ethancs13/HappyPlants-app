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
      version: 4,
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
        plant_key TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE care_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
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
  }

  Future<void> close() async => _db?.close();
}
