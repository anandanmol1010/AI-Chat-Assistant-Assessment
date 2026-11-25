import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'data/repositories/local_settings_repository.dart';
import 'data/repositories/remote_chat_repository.dart';
import 'domain/usecases/generate_reply.dart';
import 'domain/usecases/save_message.dart';
import 'presentation/blocs/chat_bloc.dart';
import 'presentation/screens/chat_screen.dart';
import 'domain/repositories/settings_repository.dart';
import 'domain/usecases/provider_settings.dart';
import 'presentation/blocs/settings_bloc.dart';
import 'presentation/screens/settings_screen.dart';

import 'data/datasources/history_database.dart';
import 'data/datasources/history_local_data_source.dart';
import 'data/repositories/sqlite_conversation_repository.dart';
import 'domain/repositories/conversation_repository.dart';
import 'domain/usecases/conversations.dart';
import 'presentation/blocs/conversation_bloc.dart';
import 'presentation/screens/conversations_screen.dart';

void main() => runApp(const AiChatAssistantApp());

typedef _Repositories = ({
  ConversationRepository history,
  SettingsRepository settings,
});

Future<_Repositories> _openRepositories() async {
  final db = await openHistoryDatabase();
  return (
    history: SqliteConversationRepository(HistoryLocalDataSource(db)),
    settings: LocalSettingsRepository(db, const FlutterSecureStorage()),
  );
}

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
  late var _history = _openRepositories();
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Repositories>(
    future: _history,
    builder: (context, snapshot) {
      final repositories = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          repositories != null) {
        final repository = repositories.history;
        final loadProvider = LoadProvider(repositories.settings);
        Widget settingsBuilder(BuildContext context) => BlocProvider(
          create: (_) => SettingsBloc(
            load: loadProvider,
            save: SaveProvider(repositories.settings),
          ),
          child: const SettingsScreen(),
        );
        return BlocProvider(
          create: (_) => ConversationBloc(
            list: GetConversations(repository),
            create: CreateConversation(repository),
            find: GetConversation(repository),
            delete: DeleteConversation(repository),
          )..add(const ConversationsRequested()),
          child: ConversationsScreen(
            settingsBuilder: settingsBuilder,
            chatBuilder: (conversation) => BlocProvider(
              create: (_) => ChatBloc(
                conversationId: conversation.id,
                getMessages: GetMessages(repository),
                saveMessage: SaveMessage(repository),
                generateReply: GenerateReply(
                  RemoteChatRepository(_dio, loadProvider),
                ),
              )..add(const ChatOpened()),
              child: ChatScreen(
                conversation: conversation,
                settingsBuilder: settingsBuilder,
              ),
            ),
          ),
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
                      onPressed: () =>
                          setState(() => _history = _openRepositories()),
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
