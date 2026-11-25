import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<Database> openHistoryDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  final database = factory ?? databaseFactory;
  return database.openDatabase(
    path ?? p.join(await database.getDatabasesPath(), 'chat_history.db'),
    options: OpenDatabaseOptions(
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 4) await _createAppPreferences(db);
        if (oldVersion < 2) {
          await _createProviderTable(db);
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE provider_settings ADD COLUMN stream_replies INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
      onCreate: (db, version) async {
        await _createAppPreferences(db);
        await _createProviderTable(db);
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT NOT NULL PRIMARY KEY,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT NOT NULL PRIMARY KEY,
            conversation_id TEXT NOT NULL
              REFERENCES conversations(id) ON DELETE CASCADE,
            role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX messages_by_conversation
            ON messages(conversation_id, timestamp)
        ''');
      },
    ),
  );
}

Future<void> _createProviderTable(Database db) => db.execute("""
  CREATE TABLE provider_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    provider_name TEXT NOT NULL,
    protocol TEXT NOT NULL,
    base_url TEXT NOT NULL,
    model TEXT NOT NULL,
    key_ref TEXT,
    stream_replies INTEGER NOT NULL DEFAULT 1
  )
""");

Future<void> _createAppPreferences(Database db) => db.execute("""
  CREATE TABLE app_preferences (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    dark_mode INTEGER NOT NULL CHECK (dark_mode IN (0, 1))
  )
""");
