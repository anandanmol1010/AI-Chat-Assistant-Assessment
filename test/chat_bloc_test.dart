import 'package:ai_chat_assistant/core/errors/failure.dart';
import 'package:ai_chat_assistant/domain/entities/message.dart';
import 'dart:async';

import 'package:ai_chat_assistant/data/datasources/history_database.dart';
import 'package:ai_chat_assistant/data/datasources/history_local_data_source.dart';
import 'package:ai_chat_assistant/data/repositories/sqlite_conversation_repository.dart';
import 'package:ai_chat_assistant/domain/repositories/chat_repository.dart';
import 'package:ai_chat_assistant/domain/usecases/conversations.dart';
import 'package:ai_chat_assistant/domain/usecases/generate_reply.dart';
import 'package:ai_chat_assistant/domain/usecases/save_message.dart';
import 'package:ai_chat_assistant/presentation/blocs/chat_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'send and retry share one gate and persist one completed turn',
    () async {
      sqfliteFfiInit();
      final db = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final repo = SqliteConversationRepository(HistoryLocalDataSource(db));
      final chat = (await repo.create()).getOrElse(
        (_) => throw StateError('Test setup failed'),
      );
      final remote = _Remote();
      final bloc = ChatBloc(
        conversationId: chat.id,
        getMessages: GetMessages(repo),
        saveMessage: SaveMessage(repo),
        generateReply: GenerateReply(remote),
      );
      addTearDown(bloc.close);

      final loaded = bloc.stream.firstWhere(
        (state) => state.phase == ChatPhase.ready,
      );
      bloc.add(const ChatOpened());
      await loaded;
      bloc.add(const MessageSent('   '));
      final accepted = bloc.stream.firstWhere(
        (state) => state.acceptedMessageId != null,
      );
      bloc.add(const MessageSent('  Hello  '));
      final first = await accepted;
      final id = first.acceptedMessageId;
      bloc.add(const MessageSent('Duplicate'));
      bloc.add(const ChatRetryRequested());

      final failed = bloc.stream.firstWhere(
        (state) => state.failure is NetworkFailure,
      );
      remote.current.add(const Left(NetworkFailure()));
      await remote.current.close();
      expect((await failed).canRetry, isTrue);
      expect(remote.histories, hasLength(1));
      expect(first.messages.single.content, 'Hello');

      final partial = bloc.stream.firstWhere(
        (state) => state.partialReply.isNotEmpty,
      );
      final answered = bloc.stream.firstWhere(
        (state) => state.phase == ChatPhase.ready && state.messages.length == 2,
      );
      final next = remote.nextRequest.stream.first;
      bloc.add(const ChatRetryRequested());
      await next;
      remote.current.add(
        const Right((text: '**Hi', modelName: 'model-at-retry')),
      );
      expect((await partial).partialReply, '**Hi');
      expect((await db.query('messages')), hasLength(1));
      remote.current.add(
        const Right((text: '**', modelName: 'model-at-retry')),
      );
      await remote.current.close();
      final complete = await answered;
      expect(complete.messages.map((message) => message.content), [
        'Hello',
        '**Hi**',
      ]);
      expect(remote.histories.last.single.id, id);
      expect((await db.query('messages')), hasLength(2));
      await remote.nextRequest.close();
    },
  );
}

class _Remote implements ChatRepository {
  final histories = <List<Message>>[];
  final nextRequest = StreamController<void>.broadcast(sync: true);
  late StreamController<Either<Failure, ReplyDelta>> current;

  @override
  Stream<Either<Failure, ReplyDelta>> reply(List<Message> history) {
    histories.add(history);
    current = StreamController<Either<Failure, ReplyDelta>>();
    nextRequest.add(null);
    return current.stream;
  }
}
