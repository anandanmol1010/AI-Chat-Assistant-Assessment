import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';
import '../repositories/conversation_repository.dart';

class GetConversations {
  const GetConversations(this.repository);
  final ConversationRepository repository;

  Future<Either<Failure, List<Conversation>>> call() => repository.list();
}

class CreateConversation {
  const CreateConversation(this.repository);
  final ConversationRepository repository;

  Future<Either<Failure, Conversation>> call() => repository.create();
}

class GetConversation {
  const GetConversation(this.repository);
  final ConversationRepository repository;

  Future<Either<Failure, Conversation?>> call(String id) => repository.find(id);
}

class DeleteConversation {
  const DeleteConversation(this.repository);
  final ConversationRepository repository;

  Future<Either<Failure, Unit>> call(String id) => repository.delete(id);
}

class GetMessages {
  const GetMessages(this.repository);
  final ConversationRepository repository;

  Future<Either<Failure, List<Message>>> call(String id) =>
      repository.messages(id);
}
