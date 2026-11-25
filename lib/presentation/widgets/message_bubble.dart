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
    final time = saved == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(saved.timestamp.toLocal()));
    final ink = isUser ? colors.onPrimaryContainer : colors.onSurface;
    final meta = isUser ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final body = theme.textTheme.bodyMedium?.copyWith(color: ink);

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isUser
                ? constraints.maxWidth * .85
                : constraints.maxWidth,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: isUser
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              border: isUser ? null : Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(isUser ? 18 : 6),
                bottomEnd: Radius.circular(isUser ? 6 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      isUser
                          ? Icons.person_outline_rounded
                          : Icons.smart_toy_outlined,
                      size: 15,
                      color: isUser ? meta : colors.primary,
                    ),
                    Text(
                      isUser ? 'You' : 'Assistant',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: meta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (time != null)
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: meta,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isUser && saved != null)
                  SelectableText(saved.content, style: body)
                else if (saved != null)
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
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                    ),
                  )
                else if (preview case final text? when text.isNotEmpty)
                  SelectableText(text, style: body)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text('Assistant is typing…', style: body),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
