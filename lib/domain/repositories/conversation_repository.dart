import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class ConversationRepository {
  Future<Either<Failure, List<Conversation>>> list({String query = ''});
  Future<Either<Failure, Conversation?>> find(String id);
  Future<Either<Failure, Conversation>> create();
  Future<Either<Failure, Unit>> delete(String id);
  Future<Either<Failure, List<Message>>> messages(String conversationId);
  Future<Either<Failure, Unit>> append(Message message);
}
