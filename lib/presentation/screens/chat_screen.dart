import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/conversation.dart';
import '../blocs/chat_bloc.dart';
import '../widgets/message_bubble.dart';
import '../widgets/screen_status.dart';

final class _DraftChanged {
  const _DraftChanged(this.text);
  final String text;
}

class _ComposerBloc extends Bloc<_DraftChanged, String> {
  _ComposerBloc() : super('') {
    on<_DraftChanged>((event, emit) => emit(event.text));
  }
}

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
  final _draftForm = GlobalKey<FormState>();
  final _draft = _ComposerBloc();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _draft.close();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ChatBloc, ChatState>(
    listener: (context, state) {
      if (state.acceptedMessageId != null) {
        _draftForm.currentState?.reset();
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
                icon: const Icon(Icons.tune_rounded),
                onPressed: state.busy
                    ? null
                    : () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: widget.settingsBuilder),
                      ),
              ),
              const SizedBox(width: 8),
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
      return const ScreenStatus(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Start the conversation',
      );
    }
    final replying = state.phase == ChatPhase.replying;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      itemCount: state.messages.length + (replying ? 1 : 0),
      itemBuilder: (context, index) {
        if (replying && index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MessageBubble.streaming(state.partialReply),
          );
        }
        final message = state
            .messages[state.messages.length - 1 - index + (replying ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MessageBubble(message: message),
        );
      },
    );
  }

  Widget _composer(BuildContext context, ChatState state, ChatBloc bloc) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 3, 6, 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Form(
                  key: _draftForm,
                  child: TextFormField(
                    onChanged: (text) => _draft.add(_DraftChanged(text)),
                    readOnly: state.busy,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Write a message',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BlocBuilder<_ComposerBloc, String>(
                bloc: _draft,
                builder: (context, draft) => IconButton.filled(
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceContainer,
                    disabledForegroundColor: colors.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: state.busy || draft.trim().isEmpty
                      ? null
                      : () => bloc.add(MessageSent(draft)),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, String message, Widget? action) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

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
