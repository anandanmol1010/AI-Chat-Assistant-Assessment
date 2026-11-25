import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../blocs/conversation_bloc.dart';
import '../widgets/screen_status.dart';
import '../widgets/theme_toggle_button.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({
    required this.chatBuilder,
    required this.settingsBuilder,
    super.key,
  });

  final Widget Function(Conversation) chatBuilder;
  final WidgetBuilder settingsBuilder;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ConversationBloc, ConversationState>(
    listener: (context, state) async {
      if (state is ConversationLoaded &&
          state.opened != null &&
          ModalRoute.isCurrentOf(context) == true) {
        FocusScope.of(context).unfocus();
        final bloc = context.read<ConversationBloc>();
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => chatBuilder(state.opened!)),
        );
        if (!bloc.isClosed) bloc.add(const ConversationsRequested());
      }
    },
    builder: (context, state) {
      final bloc = context.read<ConversationBloc>();
      final theme = Theme.of(context);
      final canCreate =
          state is ConversationLoaded ||
          state is ConversationEmpty ||
          state is ConversationNoMatches;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Text(
            'Conversations',
            style: theme.textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            const ThemeToggleButton(),
            IconButton(
              tooltip: 'Provider settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(
                context,
              ).push<bool>(MaterialPageRoute(builder: settingsBuilder)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: () => bloc.add(const ConversationCreated()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New chat'),
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: TextField(
                    onChanged: (query) =>
                        bloc.add(ConversationSearchChanged(query)),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search titles and messages',
                    ),
                  ),
                ),
                Expanded(
                  child: switch (state) {
                    ConversationLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    ConversationEmpty() => const ScreenStatus(
                      icon: Icons.forum_outlined,
                      title: 'No conversations yet.',
                      detail:
                          'Start a chat to ask a question or work through an idea.',
                    ),
                    ConversationNoMatches() => const ScreenStatus(
                      icon: Icons.search_off_rounded,
                      title: 'No conversations match your search.',
                      detail: 'Try a word from the chat title or message text.',
                    ),
                    ConversationError(:final message) => ScreenStatus(
                      icon: Icons.error_outline_rounded,
                      title: message,
                      action: TextButton(
                        onPressed: () =>
                            bloc.add(const ConversationsRequested()),
                        child: const Text('Reload'),
                      ),
                    ),
                    ConversationLoaded(:final conversations) =>
                      ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                        itemCount: conversations.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return _ConversationRow(
                            conversation: conversation,
                            onOpen: () =>
                                bloc.add(ConversationOpened(conversation.id)),
                            onDelete: () =>
                                _confirmDelete(context, conversation),
                          );
                        },
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.onOpen,
    required this.onDelete,
  });

  final Conversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = MaterialLocalizations.of(
      context,
    ).formatShortDate(conversation.updatedAt.toLocal());
    return ListTile(
      minTileHeight: 65,
      contentPadding: EdgeInsets.zero,
      title: Text(
        conversation.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        date,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: 'Conversation options',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (_) => onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete chat')),
        ],
      ),
    );
  }
}
