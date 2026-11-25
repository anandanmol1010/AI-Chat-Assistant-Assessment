import 'package:sqflite/sqflite.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../models/history_rows.dart';

class HistoryLocalDataSource {
  const HistoryLocalDataSource(this._database);

  final Database _database;

  Future<List<Conversation>> list({String query = ''}) async {
    final term = query.trim();
    final rows = term.isEmpty
        ? await _database.query('conversations', orderBy: 'updated_at DESC, id')
        : await _database.rawQuery(
            """
            SELECT c.* FROM conversations c
            WHERE instr(lower(c.title), lower(?)) > 0 OR EXISTS (
              SELECT 1 FROM messages m
              WHERE m.conversation_id = c.id
                AND instr(lower(m.content), lower(?)) > 0
            )
            ORDER BY c.updated_at DESC, c.id
          """,
            [term, term],
          );
    return rows.map(conversationFromRow).toList(growable: false);
  }

  Future<Conversation?> find(String id) async {
    final rows = await _database.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : conversationFromRow(rows.single);
  }

  Future<void> insert(Conversation conversation) async {
    await _database.insert('conversations', conversationToRow(conversation));
  }

  Future<void> delete(String id) async {
    await _database.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Message>> messages(String conversationId) async {
    final rows = await _database.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp, rowid',
    );
    return rows.map(messageFromRow).toList(growable: false);
  }

  Future<void> append(Message message) async {
    await _database.transaction((transaction) async {
      await transaction.insert('messages', messageToRow(message));
      if (message.role == MessageRole.user) {
        final title = message.content
            .trim()
            .split(RegExp(r'\s+'))
            .take(8)
            .join(' ');
        await transaction.rawUpdate(
          '''
          UPDATE conversations SET title = ?
          WHERE id = ? AND (
            SELECT COUNT(*) FROM messages
            WHERE conversation_id = ? AND role = 'user'
          ) = 1
          ''',
          [title, message.conversationId, message.conversationId],
        );
      }
      await transaction.rawUpdate(
        'UPDATE conversations SET updated_at = MAX(updated_at, ?) WHERE id = ?',
        [message.timestamp.microsecondsSinceEpoch, message.conversationId],
      );
    });
  }
}
