import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/message.dart';
import '../repositories/conversation_repository.dart';

class SaveMessage {
  const SaveMessage(this._repository);
  final ConversationRepository _repository;

  Future<Either<Failure, Unit>> call(Message message) =>
      _repository.append(message);
}
