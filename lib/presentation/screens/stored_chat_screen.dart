import 'package:fpdart/fpdart.dart' show Either;
import 'package:flutter/material.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/conversations.dart';

class StoredChatScreen extends StatefulWidget {
  const StoredChatScreen({
    required this.conversation,
    required this.getMessages,
    super.key,
  });

  final Conversation conversation;
  final GetMessages getMessages;

  @override
  State<StoredChatScreen> createState() => _StoredChatScreenState();
}

class _StoredChatScreenState extends State<StoredChatScreen> {
  late final _history = widget.getMessages(widget.conversation.id);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.conversation.title)),
    body: FutureBuilder<Either<Failure, List<Message>>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load saved messages.'));
        }
        final result = snapshot.data;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return result.match(
          (_) => const Center(child: Text('Could not load saved messages.')),
          (messages) => messages.isEmpty
              ? const Center(child: Text('No messages yet.'))
              : ListView(
                  children: [
                    for (final message in messages)
                      ListTile(
                        title: Text(message.content),
                        subtitle: Text(
                          '${message.role.name} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(message.timestamp.toLocal()))}',
                        ),
                      ),
                  ],
                ),
        );
      },
    ),
  );
}
