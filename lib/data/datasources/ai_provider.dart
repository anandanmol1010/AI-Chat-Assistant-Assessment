import '../../domain/entities/message.dart';
import '../../domain/entities/provider_config.dart';

typedef AiRequest = ({
  String endpoint,
  Map<String, Object?> headers,
  Map<String, Object?> body,
});
typedef AiChunk = ({String text, bool finished});

abstract interface class AiProvider {
  AiRequest request(ProviderConfig config, List<Message> history);
  AiChunk decode(Map<String, dynamic> body, {required bool streaming});
}

class OpenAiCompatibleProvider implements AiProvider {
  const OpenAiCompatibleProvider();

  @override
  AiRequest request(ProviderConfig config, List<Message> history) => (
    endpoint: '${config.baseUrl}/chat/completions',
    headers: {
      if (config.apiKey.isNotEmpty) 'Authorization': 'Bearer ${config.apiKey}',
    },
    body: {
      'model': config.model,
      'stream': config.streamReplies,
      'messages': [
        for (final message in history)
          {'role': message.role.name, 'content': message.content},
      ],
    },
  );

  @override
  AiChunk decode(Map<String, dynamic> body, {required bool streaming}) {
    final choices = body['choices'] as List<dynamic>;
    if (choices.isEmpty && streaming) return (text: '', finished: false);
    final choice = choices.first as Map<String, dynamic>;
    final message =
        choice[streaming ? 'delta' : 'message'] as Map<String, dynamic>?;
    return (
      text: message?['content'] as String? ?? '',
      finished: !streaming || choice['finish_reason'] != null,
    );
  }
}

class GeminiProvider implements AiProvider {
  const GeminiProvider();

  @override
  AiRequest request(ProviderConfig config, List<Message> history) {
    final model = config.model.replaceFirst(RegExp(r'^models/'), '');
    final operation = config.streamReplies
        ? 'streamGenerateContent?alt=sse'
        : 'generateContent';
    final contents = <({String role, List<Map<String, String>> parts})>[];
    final instructions = <Map<String, String>>[];
    for (final message in history) {
      final part = {'text': message.content};
      if (message.role == MessageRole.system) {
        instructions.add(part);
        continue;
      }
      final role = message.role == MessageRole.assistant ? 'model' : 'user';
      if (contents.isNotEmpty && contents.last.role == role) {
        contents.last.parts.add(part);
      } else {
        contents.add((role: role, parts: [part]));
      }
    }
    return (
      endpoint: '${config.baseUrl}/models/$model:$operation',
      headers: {'x-goog-api-key': config.apiKey},
      body: {
        'contents': [
          for (final turn in contents) {'role': turn.role, 'parts': turn.parts},
        ],
        if (instructions.isNotEmpty)
          'systemInstruction': {'parts': instructions},
      },
    );
  }

  @override
  AiChunk decode(Map<String, dynamic> body, {required bool streaming}) {
    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      if (streaming &&
          body['error'] == null &&
          body['promptFeedback'] == null) {
        return (text: '', finished: false);
      }
      throw const FormatException('Missing candidates');
    }
    final candidate = candidates.first as Map<String, dynamic>;
    final reason = candidate['finishReason'];
    if (reason != null &&
        reason != 'STOP' &&
        reason != 'MAX_TOKENS' &&
        reason != 'FINISH_REASON_UNSPECIFIED') {
      throw const FormatException('Gemini could not complete this response');
    }
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    return (
      text: parts
          .whereType<Map<String, dynamic>>()
          .where((part) => part['thought'] != true)
          .map((part) => part['text'])
          .whereType<String>()
          .join(),
      finished:
          !streaming ||
          (reason != null && reason != 'FINISH_REASON_UNSPECIFIED'),
    );
  }
}
