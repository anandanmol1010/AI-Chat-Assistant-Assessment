import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = message.role == MessageRole.user;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(message.timestamp.toLocal()));
    return Align(
      alignment: author
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: author
              ? const EdgeInsetsDirectional.only(start: 40)
              : const EdgeInsetsDirectional.only(end: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: author
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author ? 'You · $time' : 'Assistant · $time',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 6),
              if (author)
                SelectableText(message.content)
              else
                MarkdownBody(
                  data: message.content,
                  selectable: true,
                  imageBuilder: (_, _, alt) => Text(alt ?? 'Image'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
