import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

Conversation conversationFromRow(Map<String, Object?> row) => Conversation(
  id: row['id'] as String,
  title: row['title'] as String,
  createdAt: _fromEpoch(row['created_at']),
  updatedAt: _fromEpoch(row['updated_at']),
);

Map<String, Object?> conversationToRow(Conversation conversation) => {
  'id': conversation.id,
  'title': conversation.title,
  'created_at': conversation.createdAt.microsecondsSinceEpoch,
  'updated_at': conversation.updatedAt.microsecondsSinceEpoch,
};

Message messageFromRow(Map<String, Object?> row) => Message(
  id: row['id'] as String,
  conversationId: row['conversation_id'] as String,
  role: MessageRole.values.byName(row['role'] as String),
  content: row['content'] as String,
  timestamp: _fromEpoch(row['timestamp']),
);

Map<String, Object?> messageToRow(Message message) => {
  'id': message.id,
  'conversation_id': message.conversationId,
  'role': message.role.name,
  'content': message.content,
  'timestamp': message.timestamp.microsecondsSinceEpoch,
};

DateTime _fromEpoch(Object? value) =>
    DateTime.fromMicrosecondsSinceEpoch(value as int, isUtc: true);
