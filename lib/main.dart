import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'data/repositories/local_settings_repository.dart';
import 'data/repositories/sqlite_theme_preferences.dart';
import 'domain/repositories/theme_preferences.dart';
import 'presentation/blocs/theme_bloc.dart';
import 'data/repositories/remote_chat_repository.dart';
import 'domain/usecases/generate_reply.dart';
import 'domain/usecases/save_message.dart';
import 'presentation/blocs/chat_bloc.dart';
import 'presentation/screens/chat_screen.dart';
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
import 'presentation/theme/app_theme.dart';

void main() => runApp(const AiChatAssistantApp());

typedef _Repositories = ({
  ConversationRepository history,
  LocalSettingsRepository settings,
  ThemePreferences theme,
});

Future<_Repositories> _openRepositories() async {
  final db = await openHistoryDatabase();
  return (
    history: SqliteConversationRepository(HistoryLocalDataSource(db)),
    settings: LocalSettingsRepository(db, const FlutterSecureStorage()),
    theme: SqliteThemePreferences(db),
  );
}

final class _StartupRequested {
  const _StartupRequested();
}

class _StartupBloc
    extends Bloc<_StartupRequested, AsyncSnapshot<_Repositories>> {
  _StartupBloc() : super(const AsyncSnapshot.waiting()) {
    on<_StartupRequested>((event, emit) async {
      emit(const AsyncSnapshot.waiting());
      try {
        emit(
          AsyncSnapshot.withData(
            ConnectionState.done,
            await _openRepositories(),
          ),
        );
      } catch (error, stack) {
        emit(AsyncSnapshot.withError(ConnectionState.done, error, stack));
      }
    }, transformer: droppable());
  }
}

class AiChatAssistantApp extends StatelessWidget {
  const AiChatAssistantApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _StartupBloc()..add(const _StartupRequested()),
    child: BlocBuilder<_StartupBloc, AsyncSnapshot<_Repositories>>(
      builder: (context, snapshot) {
        final repositories = snapshot.data;
        if (repositories == null) return _materialApp(false);
        return BlocProvider(
          create: (_) =>
              ThemeBloc(repositories.theme)..add(const ThemeRequested()),
          child: BlocBuilder<ThemeBloc, ThemeState>(
            buildWhen: (previous, current) => previous.dark != current.dark,
            builder: (context, theme) => _materialApp(theme.dark),
          ),
        );
      },
    ),
  );

  Widget _materialApp(bool dark) => MaterialApp(
    title: 'AI Chat Assistant',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: const _HistoryStartup(),
  );
}

class _HistoryStartup extends StatefulWidget {
  const _HistoryStartup();

  @override
  State<_HistoryStartup> createState() => _HistoryStartupState();
}

class _HistoryStartupState extends State<_HistoryStartup> {
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
  Widget build(BuildContext context) =>
      BlocBuilder<_StartupBloc, AsyncSnapshot<_Repositories>>(
        builder: (context, snapshot) {
          final repositories = snapshot.data;
          if (snapshot.connectionState == ConnectionState.done &&
              repositories != null) {
            final repository = repositories.history;
            final loadProvider = LoadProvider(repositories.settings);
            Widget settingsBuilder(BuildContext context) => BlocProvider(
              create: (_) => SettingsBloc(
                load: loadProvider,
                profiles: ManageProviderProfiles(repositories.settings),
              )..add(const SettingsRequested()),
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
            appBar: AppBar(
              titleSpacing: 20,
              title: Text(
                'Conversations',
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not open local storage.'),
                        TextButton(
                          onPressed: () => context.read<_StartupBloc>().add(
                            const _StartupRequested(),
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
