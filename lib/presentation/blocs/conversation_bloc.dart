import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/usecases/conversations.dart';

sealed class ConversationEvent {
  const ConversationEvent();
}

final class ConversationsRequested extends ConversationEvent {
  const ConversationsRequested();
}

final class ConversationCreated extends ConversationEvent {
  const ConversationCreated();
}

final class ConversationOpened extends ConversationEvent {
  const ConversationOpened(this.id);
  final String id;
}

final class ConversationDeleted extends ConversationEvent {
  const ConversationDeleted(this.id);
  final String id;
}

sealed class ConversationState {
  const ConversationState();
}

final class ConversationLoading extends ConversationState {
  const ConversationLoading();
}

final class ConversationEmpty extends ConversationState {
  const ConversationEmpty();
}

final class ConversationLoaded extends ConversationState {
  const ConversationLoaded(this.conversations, {this.opened});
  final List<Conversation> conversations;
  final Conversation? opened;
}

final class ConversationError extends ConversationState {
  const ConversationError(this.message);
  final String message;
}

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required this._list,
    required this._create,
    required this._find,
    required this._delete,
  }) : super(const ConversationLoading()) {
    on<ConversationEvent>(_handle, transformer: sequential());
  }

  final GetConversations _list;
  final CreateConversation _create;
  final GetConversation _find;
  final DeleteConversation _delete;

  Future<void> _handle(
    ConversationEvent event,
    Emitter<ConversationState> emit,
  ) async {
    switch (event) {
      case ConversationsRequested():
        emit(const ConversationLoading());
        await _refresh(emit);
      case ConversationCreated():
        final result = await _create();
        await result.match(
          (_) async =>
              emit(const ConversationError('Could not create a chat.')),
          (chat) => _refresh(emit, opened: chat),
        );
      case ConversationOpened(:final id):
        final result = await _find(id);
        await result.match(
          (_) async =>
              emit(const ConversationError('Could not open this chat.')),
          (chat) => _refresh(emit, opened: chat),
        );
      case ConversationDeleted(:final id):
        final result = await _delete(id);
        await result.match(
          (_) async =>
              emit(const ConversationError('Could not delete this chat.')),
          (_) => _refresh(emit),
        );
    }
  }

  Future<void> _refresh(
    Emitter<ConversationState> emit, {
    Conversation? opened,
  }) async {
    final result = await _list();
    emit(
      result.match(
        (_) => const ConversationError('Could not load your conversations.'),
        (chats) => chats.isEmpty
            ? const ConversationEmpty()
            : ConversationLoaded(List.unmodifiable(chats), opened: opened),
      ),
    );
  }
}
