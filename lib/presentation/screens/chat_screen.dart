import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/conversation.dart';
import '../blocs/chat_bloc.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.conversation,
    required this.settingsBuilder,
    super.key,
  });

  final Conversation conversation;
  final WidgetBuilder settingsBuilder;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ChatBloc, ChatState>(
    listener: (context, state) {
      if (state.acceptedMessageId != null) {
        _draft.clear();
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    },
    builder: (context, state) {
      final bloc = context.read<ChatBloc>();
      return PopScope(
        canPop: !state.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.conversation.title,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Provider settings',
                icon: const Icon(Icons.tune),
                onPressed: state.busy
                    ? null
                    : () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: widget.settingsBuilder),
                      ),
              ),
            ],
          ),
          body: SafeArea(
            child: switch (state.phase) {
              ChatPhase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              ChatPhase.historyError => Center(
                child: TextButton.icon(
                  onPressed: () => bloc.add(const ChatOpened()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Could not load messages. Retry'),
                ),
              ),
              _ => Column(
                children: [
                  Expanded(child: _history(state)),
                  if (state.failure case final failure?)
                    _notice(
                      context,
                      _describe(failure),
                      state.canRetry
                          ? TextButton(
                              onPressed: () =>
                                  bloc.add(const ChatRetryRequested()),
                              child: const Text('Retry'),
                            )
                          : null,
                    )
                  else if (state.canRetry)
                    _notice(
                      context,
                      'The last message has no reply.',
                      TextButton(
                        onPressed: () => bloc.add(const ChatRetryRequested()),
                        child: const Text('Retry'),
                      ),
                    ),
                  if (state.busy)
                    LinearProgressIndicator(
                      semanticsLabel: state.phase == ChatPhase.saving
                          ? 'Saving message'
                          : 'Waiting for provider',
                    ),
                  _composer(context, state, bloc),
                ],
              ),
            },
          ),
        ),
      );
    },
  );

  Widget _history(ChatState state) {
    if (state.messages.isEmpty) {
      return const Center(child: Text('Send a message to start this chat.'));
    }
    final replying = state.phase == ChatPhase.replying;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: state.messages.length + (replying ? 1 : 0),
      itemBuilder: (context, index) {
        if (replying && index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: state.partialReply.isEmpty
                ? const Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Assistant is typing…'),
                    ],
                  )
                : SelectableText(state.partialReply),
          );
        }
        final message = state
            .messages[state.messages.length - 1 - index + (replying ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MessageBubble(message: message),
        );
      },
    );
  }

  Widget _composer(BuildContext context, ChatState state, ChatBloc bloc) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _draft,
                readOnly: state.busy,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _draft,
              builder: (context, draft, _) => IconButton.filled(
                tooltip: 'Send message',
                onPressed: state.busy || draft.text.trim().isEmpty
                    ? null
                    : () => bloc.add(MessageSent(draft.text)),
                icon: const Icon(Icons.arrow_upward),
              ),
            ),
          ],
        ),
      );

  Widget _notice(BuildContext context, String message, Widget? action) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ?action,
          ],
        ),
      );

  String _describe(Failure failure) => switch (failure) {
    ConfigFailure(:final message) => message,
    NetworkFailure() =>
      'Could not reach the provider. Check your connection and retry.',
    TimeoutFailure() => 'The provider took too long to reply. Try again.',
    AuthFailure() =>
      'The provider did not accept your API key. Check Settings.',
    RateLimitFailure() =>
      'The provider rate limit was reached. Wait and retry.',
    InvalidResponseFailure() =>
      'The provider returned an incomplete or invalid reply.',
    ServerFailure() =>
      'The provider is temporarily unavailable. Try again later.',
    StorageFailure() => 'Could not save to local storage. Try again.',
  };
}
