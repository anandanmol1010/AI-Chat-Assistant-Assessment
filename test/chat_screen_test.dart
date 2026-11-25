import 'dart:async';

import 'package:ai_chat_assistant/core/errors/failure.dart';
import 'package:ai_chat_assistant/domain/entities/conversation.dart';
import 'package:ai_chat_assistant/domain/entities/message.dart';
import 'package:ai_chat_assistant/domain/repositories/chat_repository.dart';
import 'package:ai_chat_assistant/domain/repositories/conversation_repository.dart';
import 'package:ai_chat_assistant/domain/usecases/conversations.dart';
import 'package:ai_chat_assistant/domain/usecases/generate_reply.dart';
import 'package:ai_chat_assistant/domain/usecases/save_message.dart';
import 'package:ai_chat_assistant/presentation/blocs/chat_bloc.dart';
import 'package:ai_chat_assistant/presentation/screens/chat_screen.dart';
import 'package:ai_chat_assistant/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets('composer retains unsaved input and renders a finished reply', (
    tester,
  ) async {
    final store = _ConversationStore();
    final remote = _Reply();
    final chat = Conversation(
      id: 'chat',
      title: 'New chat',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final bloc = ChatBloc(
      conversationId: chat.id,
      getMessages: GetMessages(store),
      saveMessage: SaveMessage(store),
      generateReply: GenerateReply(remote),
    )..add(const ChatOpened());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider.value(
          value: bloc,
          child: ChatScreen(
            conversation: chat,
            settingsBuilder: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    final editable = find.descendant(
      of: input,
      matching: find.byType(EditableText),
    );
    final send = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Send message',
    );
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(input, 'First line\nSecond line');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    expect(
      tester.widget<EditableText>(editable).controller.text,
      'First line\nSecond line',
    );
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    expect(find.bySemanticsLabel('Saving message'), findsOneWidget);
    store.pending.complete(const Left(StorageFailure()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(editable).controller.text,
      'First line\nSecond line',
    );
    expect(
      find.text('Could not save to local storage. Try again.'),
      findsOneWidget,
    );

    store.pending = Completer<Either<Failure, Unit>>();
    await tester.tap(send);
    await tester.pump();
    store.pending.complete(const Right(unit));
    await tester.pump();
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    expect(find.text('Assistant is typing…'), findsOneWidget);
    remote.events.add(const Right('**Done**'));
    await tester.pump();
    expect(find.text('**Done**'), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for provider'), findsOneWidget);
    unawaited(remote.events.close());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
      '**Done**',
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
    await tester.pump();
  });
}

class _ConversationStore implements ConversationRepository {
  var pending = Completer<Either<Failure, Unit>>();

  @override
  Future<Either<Failure, List<Message>>> messages(
    String conversationId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, Unit>> append(Message message) =>
      message.role == MessageRole.user
      ? pending.future
      : Future.value(const Right(unit));

  @override
  Future<Either<Failure, Conversation>> create() => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> delete(String id) => throw UnimplementedError();
  @override
  Future<Either<Failure, Conversation?>> find(String id) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<Conversation>>> list({String query = ''}) =>
      throw UnimplementedError();
}

class _Reply implements ChatRepository {
  final events = StreamController<Either<Failure, String>>();
  @override
  Stream<Either<Failure, String>> reply(List<Message> history) => events.stream;
}
