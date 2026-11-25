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
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE messages ADD COLUMN model_name TEXT');
        }
        if (oldVersion < 4) await _createAppPreferences(db);
        if (oldVersion < 2) {
          await _createProviderTable(db);
        } else {
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE provider_settings ADD COLUMN stream_replies INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (oldVersion < 5) await _migrateProviderProfiles(db);
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
            timestamp INTEGER NOT NULL,
            model_name TEXT
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

Future<void> _createProviderTable(Database db) async {
  await db.execute("""
  CREATE TABLE provider_settings (
    id INTEGER PRIMARY KEY,
    active INTEGER NOT NULL CHECK (active IN (0, 1)),
    provider_name TEXT NOT NULL,
    protocol TEXT NOT NULL,
    base_url TEXT NOT NULL,
    model TEXT NOT NULL,
    key_ref TEXT,
    stream_replies INTEGER NOT NULL DEFAULT 1
  )
""");
  await db.execute(
    'CREATE UNIQUE INDEX active_provider ON provider_settings(active) WHERE active = 1',
  );
}

Future<void> _migrateProviderProfiles(Database db) async {
  await db.execute(
    'ALTER TABLE provider_settings RENAME TO legacy_provider_settings',
  );
  await _createProviderTable(db);
  await db.execute("""
    INSERT INTO provider_settings (id, active, provider_name, protocol, base_url, model, key_ref, stream_replies)
    SELECT id, 1, provider_name, protocol, base_url, model, key_ref, stream_replies
    FROM legacy_provider_settings
  """);
  await db.execute('DROP TABLE legacy_provider_settings');
}

Future<void> _createAppPreferences(Database db) => db.execute("""
  CREATE TABLE app_preferences (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    dark_mode INTEGER NOT NULL CHECK (dark_mode IN (0, 1))
  )
""");
