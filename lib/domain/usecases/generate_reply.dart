import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class GenerateReply {
  const GenerateReply(this._repository);
  final ChatRepository _repository;

  Stream<Either<Failure, ReplyDelta>> call(List<Message> history) =>
      _repository.reply(history);
}
