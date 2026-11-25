import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/history_local_data_source.dart';

class SqliteConversationRepository implements ConversationRepository {
  const SqliteConversationRepository(this._local);

  final HistoryLocalDataSource _local;

  @override
  Future<Either<Failure, List<Conversation>>> list() => _read(_local.list);

  @override
  Future<Either<Failure, Conversation?>> find(String id) =>
      _read(() => _local.find(id));

  @override
  Future<Either<Failure, Conversation>> create() => _read(() async {
    final now = DateTime.now().toUtc();
    final conversation = Conversation(
      id: const Uuid().v4(),
      title: 'New chat',
      createdAt: now,
      updatedAt: now,
    );
    await _local.insert(conversation);
    return conversation;
  });

  @override
  Future<Either<Failure, Unit>> delete(String id) => _read(() async {
    await _local.delete(id);
    return unit;
  });

  @override
  Future<Either<Failure, List<Message>>> messages(String conversationId) =>
      _read(() => _local.messages(conversationId));

  @override
  Future<Either<Failure, Unit>> append(Message message) => _read(() async {
    await _local.append(message);
    return unit;
  });

  Future<Either<Failure, T>> _read<T>(Future<T> Function() operation) async {
    try {
      return Right(await operation());
    } on DatabaseException {
      return const Left(StorageFailure());
    }
  }
}
