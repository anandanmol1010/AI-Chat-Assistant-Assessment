import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/message.dart';

typedef ReplyDelta = ({String text, String modelName});

abstract interface class ChatRepository {
  Stream<Either<Failure, ReplyDelta>> reply(List<Message> history);
}
