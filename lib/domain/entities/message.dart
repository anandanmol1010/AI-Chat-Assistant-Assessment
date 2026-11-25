enum MessageRole { user, assistant, system }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
}
