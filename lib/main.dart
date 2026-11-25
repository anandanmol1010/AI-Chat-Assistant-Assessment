import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'data/repositories/local_settings_repository.dart';
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

  @override
  Widget build(BuildContext context) => FutureBuilder<_Repositories>(
    future: _history,
    builder: (context, snapshot) {
      final repositories = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          repositories != null) {
        final repository = repositories.history;
        return BlocProvider(
          create: (_) => ConversationBloc(
            list: GetConversations(repository),
            create: CreateConversation(repository),
            find: GetConversation(repository),
            delete: DeleteConversation(repository),
          )..add(const ConversationsRequested()),
          child: ConversationsScreen(
            getMessages: GetMessages(repository),
            settingsBuilder: (_) => BlocProvider(
              create: (_) => SettingsBloc(
                load: LoadProvider(repositories.settings),
                save: SaveProvider(repositories.settings),
              ),
              child: const SettingsScreen(),
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
