import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/conversations.dart';
import '../../domain/usecases/generate_reply.dart';
import '../../domain/usecases/save_message.dart';

sealed class ChatEvent {
  const ChatEvent();
}

final class ChatOpened extends ChatEvent {
  const ChatOpened();
}

final class MessageSent extends ChatEvent {
  const MessageSent(this.text);
  final String text;
}

final class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested();
}

enum ChatPhase { loading, ready, saving, replying, historyError }

class ChatState {
  const ChatState({
    this.phase = ChatPhase.loading,
    this.messages = const [],
    this.partialReply = '',
    this.failure,
    this.acceptedMessageId,
  });

  final ChatPhase phase;
  final List<Message> messages;
  final String partialReply;
  final Failure? failure;
  final String? acceptedMessageId;

  bool get busy => phase == ChatPhase.saving || phase == ChatPhase.replying;
  bool get canRetry =>
      !busy &&
      phase == ChatPhase.ready &&
      messages.isNotEmpty &&
      messages.last.role == MessageRole.user;
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this._conversationId,
    required this._getMessages,
    required this._saveMessage,
    required this._generateReply,
  }) : super(const ChatState()) {
    // Register all request-related events together so send and retry share one gate.
    on<ChatEvent>(_handle, transformer: droppable());
  }

  final String _conversationId;
  final GetMessages _getMessages;
  final SaveMessage _saveMessage;
  final GenerateReply _generateReply;

  Future<void> _handle(ChatEvent event, Emitter<ChatState> emit) async {
    switch (event) {
      case ChatOpened():
        emit(const ChatState());
        final result = await _getMessages(_conversationId);
        emit(
          result.match(
            (failure) =>
                ChatState(phase: ChatPhase.historyError, failure: failure),
            (messages) => ChatState(
              phase: ChatPhase.ready,
              messages: List.unmodifiable(messages),
            ),
          ),
        );
      case MessageSent(:final text):
        final content = text.trim();
        if (state.phase != ChatPhase.ready || content.isEmpty) return;
        final history = state.messages;
        emit(ChatState(phase: ChatPhase.saving, messages: history));
        final message = _message(content, MessageRole.user, history);
        final saved = await _saveMessage(message);
        final failure = saved.fold<Failure?>((failure) => failure, (_) => null);
        if (failure != null) {
          emit(
            ChatState(
              phase: ChatPhase.ready,
              messages: history,
              failure: failure,
            ),
          );
          return;
        }
        await _reply(
          List.unmodifiable([...history, message]),
          emit,
          acceptedId: message.id,
        );
      case ChatRetryRequested():
        if (state.canRetry) await _reply(state.messages, emit);
    }
  }

  Future<void> _reply(
    List<Message> history,
    Emitter<ChatState> emit, {
    String? acceptedId,
  }) async {
    emit(
      ChatState(
        phase: ChatPhase.replying,
        messages: history,
        acceptedMessageId: acceptedId,
      ),
    );
    final buffer = StringBuffer();
    await for (final item in _generateReply(history)) {
      if (emit.isDone) return;
      final failure = item.fold<Failure?>((failure) => failure, (_) => null);
      if (failure != null) {
        emit(
          ChatState(
            phase: ChatPhase.ready,
            messages: history,
            failure: failure,
          ),
        );
        return;
      }
      buffer.write(item.getOrElse((_) => ''));
      emit(
        ChatState(
          phase: ChatPhase.replying,
          messages: history,
          partialReply: buffer.toString(),
        ),
      );
    }
    if (emit.isDone) return;
    if (buffer.toString().trim().isEmpty) {
      emit(
        ChatState(
          phase: ChatPhase.ready,
          messages: history,
          failure: const InvalidResponseFailure(),
        ),
      );
      return;
    }
    final reply = _message(buffer.toString(), MessageRole.assistant, history);
    final result = await _saveMessage(reply);
    emit(
      result.match(
        (failure) => ChatState(
          phase: ChatPhase.ready,
          messages: history,
          failure: failure,
        ),
        (_) => ChatState(
          phase: ChatPhase.ready,
          messages: List.unmodifiable([...history, reply]),
        ),
      ),
    );
  }

  Message _message(String content, MessageRole role, List<Message> history) {
    final now = DateTime.now().toUtc();
    final previous = history.lastOrNull?.timestamp;
    final timestamp = previous == null || now.isAfter(previous)
        ? now
        : previous.add(const Duration(microseconds: 1));
    return Message(
      id: const Uuid().v4(),
      conversationId: _conversationId,
      role: role,
      content: content,
      timestamp: timestamp,
    );
  }
}
