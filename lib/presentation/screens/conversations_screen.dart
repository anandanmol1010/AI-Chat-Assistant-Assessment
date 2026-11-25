import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/usecases/conversations.dart';
import '../blocs/conversation_bloc.dart';
import 'stored_chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({
    required this.getMessages,
    required this.settingsBuilder,
    super.key,
  });

  final GetMessages getMessages;
  final WidgetBuilder settingsBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationBloc, ConversationState>(
      listener: (context, state) async {
        if (state is ConversationLoaded &&
            state.opened != null &&
            ModalRoute.isCurrentOf(context) == true) {
          final bloc = context.read<ConversationBloc>();
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => StoredChatScreen(
                conversation: state.opened!,
                getMessages: getMessages,
              ),
            ),
          );
          if (!bloc.isClosed) bloc.add(const ConversationsRequested());
        }
      },
      builder: (context, state) {
        final bloc = context.read<ConversationBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Chat Assistant'),
            actions: [
              IconButton(
                tooltip: 'Provider settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(
                  context,
                ).push<bool>(MaterialPageRoute(builder: settingsBuilder)),
              ),
            ],
          ),
          body: switch (state) {
            ConversationLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ConversationEmpty() => const Center(
              child: Text('No conversations yet.'),
            ),
            ConversationError(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  TextButton(
                    onPressed: () => bloc.add(const ConversationsRequested()),
                    child: const Text('Reload'),
                  ),
                ],
              ),
            ),
            ConversationLoaded(:final conversations) => ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final chat = conversations[index];
                return ListTile(
                  title: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatShortDate(chat.updatedAt.toLocal()),
                  ),
                  onTap: () => bloc.add(ConversationOpened(chat.id)),
                  trailing: IconButton(
                    tooltip: 'Delete chat',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, chat),
                  ),
                );
              },
            ),
          },
          floatingActionButton: switch (state) {
            ConversationEmpty() ||
            ConversationLoaded() => FloatingActionButton.extended(
              onPressed: () => bloc.add(const ConversationCreated()),
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
            ),
            _ => null,
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Conversation chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('The messages in “${chat.title}” will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ConversationBloc>().add(ConversationDeleted(chat.id));
    }
  }
}
