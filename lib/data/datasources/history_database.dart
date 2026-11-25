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
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
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
