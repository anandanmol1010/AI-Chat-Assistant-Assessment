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
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createProviderTable(db);
      },
      onCreate: (db, version) async {
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
    key_ref TEXT
  )
""");
