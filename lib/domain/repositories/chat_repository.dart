import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/message.dart';

abstract interface class ChatRepository {
  Stream<Either<Failure, String>> reply(List<Message> history);
}
