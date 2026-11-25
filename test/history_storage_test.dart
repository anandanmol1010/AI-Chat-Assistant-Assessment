import 'dart:io';

import 'package:ai_chat_assistant/data/datasources/history_database.dart';
import 'package:ai_chat_assistant/data/datasources/history_local_data_source.dart';
import 'package:ai_chat_assistant/data/repositories/sqlite_conversation_repository.dart';
import 'package:ai_chat_assistant/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'history survives reopening and deletion cascades to messages',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('chat_history_');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'history.db');
      final db = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      final repository = SqliteConversationRepository(
        HistoryLocalDataSource(db),
      );
      final conversation = (await repository.create()).getOrElse(
        (_) => throw StateError('Conversation could not be created'),
      );
      final timestamp = conversation.createdAt.add(const Duration(seconds: 1));
      final userMessage = Message(
        id: 'user-1',
        conversationId: conversation.id,
        role: MessageRole.user,
        content: '  Plan a Flutter project  ',
        timestamp: timestamp,
      );
      try {
        expect((await repository.append(userMessage)).isRight(), isTrue);
        expect((await repository.append(userMessage)).isLeft(), isTrue);
      } finally {
        await db.close();
      }

      final reopened = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      addTearDown(reopened.close);
      final restored = SqliteConversationRepository(
        HistoryLocalDataSource(reopened),
      );
      final chats = (await restored.list()).getOrElse(
        (_) => throw StateError('History could not be loaded'),
      );
      expect(chats.single.title, 'Plan a Flutter project');
      expect(chats.single.updatedAt, timestamp);
      final messages = (await restored.messages(
        conversation.id,
      )).getOrElse((_) => throw StateError('Messages could not be loaded'));
      expect(messages.single.content, userMessage.content);
      expect((await restored.delete(conversation.id)).isRight(), isTrue);
      expect(await reopened.query('messages'), isEmpty);
      expect((await restored.append(userMessage)).isLeft(), isTrue);
    },
  );
}
