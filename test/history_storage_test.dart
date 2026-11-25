import 'dart:io';

import 'package:ai_chat_assistant/data/datasources/history_database.dart';
import 'package:ai_chat_assistant/data/datasources/history_local_data_source.dart';
import 'package:ai_chat_assistant/data/repositories/sqlite_conversation_repository.dart';
import 'package:ai_chat_assistant/domain/entities/message.dart';
import 'package:ai_chat_assistant/domain/usecases/conversations.dart';
import 'package:ai_chat_assistant/presentation/blocs/conversation_bloc.dart';
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

  test(
    'search finds titles and saved messages once and treats punctuation literally',
    () async {
      sqfliteFfiInit();
      final db = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final repository = SqliteConversationRepository(
        HistoryLocalDataSource(db),
      );
      final chat = (await repository.create()).getOrElse(
        (_) => throw StateError('Setup failed'),
      );
      final other = (await repository.create()).getOrElse(
        (_) => throw StateError('Setup failed'),
      );
      for (final (id, role, content) in [
        ('prompt', MessageRole.user, 'Build a Flutter feature'),
        ('reply', MessageRole.assistant, 'Flutter needs a 50% budget'),
      ]) {
        expect(
          (await repository.append(
            Message(
              id: id,
              conversationId: chat.id,
              role: role,
              content: content,
              timestamp: DateTime.utc(2026),
            ),
          )).isRight(),
          isTrue,
        );
      }
      Future<List<String>> ids(String query) async =>
          (await repository.list(query: query))
              .getOrElse((_) => throw StateError('Search failed'))
              .map((conversation) => conversation.id)
              .toList();
      expect(await ids(' FLUTTER '), [chat.id]);
      expect(await ids('50%'), [chat.id]);
      expect(await ids('_'), isEmpty);
      expect(await ids('new chat'), [other.id]);
      expect(await ids(''), unorderedEquals([chat.id, other.id]));
    },
  );

  test('ConversationBloc creates, opens, and deletes SQLite chats', () async {
    sqfliteFfiInit();
    final db = await openHistoryDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final repository = SqliteConversationRepository(HistoryLocalDataSource(db));
    final bloc = ConversationBloc(
      list: GetConversations(repository),
      create: CreateConversation(repository),
      find: GetConversation(repository),
      delete: DeleteConversation(repository),
    );
    addTearDown(bloc.close);

    Future<ConversationState> dispatch(ConversationEvent event) {
      final state = bloc.stream.firstWhere(
        (state) => state is! ConversationLoading,
      );
      bloc.add(event);
      return state;
    }

    expect(
      await dispatch(const ConversationsRequested()),
      isA<ConversationEmpty>(),
    );
    final created =
        await dispatch(const ConversationCreated()) as ConversationLoaded;
    final chat = created.conversations.single;
    expect(created.opened?.id, chat.id);

    final opened =
        await dispatch(ConversationOpened(chat.id)) as ConversationLoaded;
    expect(opened.opened?.id, chat.id);
    expect(
      await dispatch(ConversationDeleted(chat.id)),
      isA<ConversationEmpty>(),
    );
  });
}
