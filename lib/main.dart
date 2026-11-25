import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/datasources/history_database.dart';
import 'data/datasources/history_local_data_source.dart';
import 'data/repositories/sqlite_conversation_repository.dart';
import 'domain/repositories/conversation_repository.dart';
import 'domain/usecases/conversations.dart';
import 'presentation/blocs/conversation_bloc.dart';
import 'presentation/screens/conversations_screen.dart';

void main() => runApp(const AiChatAssistantApp());

Future<ConversationRepository> openConversationRepository() async =>
    SqliteConversationRepository(
      HistoryLocalDataSource(await openHistoryDatabase()),
    );

class AiChatAssistantApp extends StatelessWidget {
  const AiChatAssistantApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AI Chat Assistant',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF206B54)),
    home: const _HistoryStartup(),
  );
}

class _HistoryStartup extends StatefulWidget {
  const _HistoryStartup();

  @override
  State<_HistoryStartup> createState() => _HistoryStartupState();
}

class _HistoryStartupState extends State<_HistoryStartup> {
  late var _history = openConversationRepository();

  @override
  Widget build(BuildContext context) => FutureBuilder<ConversationRepository>(
    future: _history,
    builder: (context, snapshot) {
      final repository = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          repository != null) {
        return BlocProvider(
          create: (_) => ConversationBloc(
            list: GetConversations(repository),
            create: CreateConversation(repository),
            find: GetConversation(repository),
            delete: DeleteConversation(repository),
          )..add(const ConversationsRequested()),
          child: ConversationsScreen(getMessages: GetMessages(repository)),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('AI Chat Assistant')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not open local storage.'),
                    TextButton(
                      onPressed: () => setState(
                        () => _history = openConversationRepository(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
