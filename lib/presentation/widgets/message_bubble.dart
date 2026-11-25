import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required Message this.message, super.key})
    : preview = null;

  const MessageBubble.streaming(String this.preview, {super.key})
    : message = null;

  final Message? message;
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final saved = message;
    final isUser = saved?.role == MessageRole.user;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.55);
    final metadata = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final time = saved == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(saved.timestamp.toLocal()));

    if (isUser && saved != null) {
      return LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .83),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: SelectableText(saved.content, style: body),
                  ),
                ),
                const SizedBox(height: 4),
                Text('You · $time', style: metadata),
              ],
            ),
          ),
        ),
      );
    }
    if (saved != null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: saved.content,
              selectable: true,
              imageBuilder: (_, _, alt) => Text(alt ?? 'Image'),
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: body,
                code: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colors.onSurface,
                  backgroundColor: colors.surfaceContainer,
                ),
                codeblockDecoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                codeblockPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(saved.modelName ?? 'Assistant', style: metadata),
                Text('· $time', style: metadata),
              ],
            ),
          ],
        ),
      );
    }
    if (preview case final text? when text.isNotEmpty) {
      return SelectableText(text, style: body);
    }
    return Row(
      children: [
        const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('Assistant is typing…', style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
