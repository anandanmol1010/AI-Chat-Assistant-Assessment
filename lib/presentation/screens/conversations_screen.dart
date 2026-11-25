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
      final colors = theme.colorScheme;
      final canCreate =
          state is ConversationLoaded ||
          state is ConversationEmpty ||
          state is ConversationNoMatches;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'AI Chat Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Text(
                    'Conversations',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        itemCount: conversations.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return _ConversationCard(
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
        bottomNavigationBar: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canCreate
                        ? () => bloc.add(const ConversationCreated())
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New chat'),
                  ),
                ),
              ),
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

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
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
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        minTileHeight: 76,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          conversation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          'Updated $date',
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
      ),
    );
  }
}
