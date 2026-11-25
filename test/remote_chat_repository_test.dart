import 'package:ai_chat_assistant/core/errors/failure.dart';
import 'package:ai_chat_assistant/domain/entities/message.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_chat_assistant/data/repositories/remote_chat_repository.dart';
import 'package:ai_chat_assistant/domain/entities/provider_config.dart';
import 'package:ai_chat_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_chat_assistant/domain/usecases/provider_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  final history = [
    Message(
      id: 'm1',
      conversationId: 'c1',
      role: MessageRole.user,
      content: 'Hello',
      timestamp: DateTime.utc(2026),
    ),
  ];

  test(
    'OpenAI-compatible adapter sends history and decodes streamed deltas',
    () async {
      final repo = _repository(ProviderProtocol.compatible, (request, body) {
        expect(request.uri.path, '/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer fixture');
        expect(body['messages'], [
          {'role': 'user', 'content': 'Hello'},
        ]);
        expect(body['stream'], true);
        return _sse([
          'data: {"choices":[{"delta":{"content":"Hé"}}]}\r\n\r\n',
          'data: {"choices":[{"delta":{"content":"llo"},"finish_reason":"stop"}]}\n\n',
        ]);
      });
      final reply = await repo.reply(history).toList();
      expect(
        reply.map((event) => event.getOrElse((_) => 'failure')).join(),
        'Héllo',
      );
    },
  );

  test(
    'Gemini sends model turns and decodes text without thought parts',
    () async {
      final repo = _repository(ProviderProtocol.gemini, (request, body) {
        expect(request.uri.path, '/v1/models/example:streamGenerateContent');
        expect(request.uri.queryParameters, {'alt': 'sse'});
        expect(request.headers['x-goog-api-key'], 'fixture');
        expect(body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': 'Hello'},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Hi'},
            ],
          },
        ]);
        return _sse([
          'data: {"candidates":[{"content":{"parts":[{"thought":true,"text":"hidden"},{"text":"OK"}]},"finishReason":"STOP"}]}\n\n',
        ]);
      });
      final reply = await repo.reply([
        ...history,
        Message(
          id: 'm2',
          conversationId: 'c1',
          role: MessageRole.assistant,
          content: 'Hi',
          timestamp: DateTime.utc(2026),
        ),
      ]).toList();
      expect(reply.single.getOrElse((_) => 'failure'), 'OK');
    },
  );

  test('OpenAI can request a single JSON reply', () async {
    final repo = _repository(ProviderProtocol.openAi, (_, body) {
      expect(body['stream'], false);
      return ResponseBody.fromString(
        '{"choices":[{"message":{"content":"Done"}}]}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }, streaming: false);
    expect(
      (await repo.reply(history).single).getOrElse((_) => 'failure'),
      'Done',
    );
  });

  test('Gemini distinguishes an invalid key from a generic HTTP 400', () async {
    for (final streaming in [true, false]) {
      for (final (reason, matcher) in [
        ('API_KEY_INVALID', isA<AuthFailure>()),
        ('INVALID_MODEL', isA<ConfigFailure>()),
      ]) {
        final repo = _repository(
          ProviderProtocol.gemini,
          (_, _) => ResponseBody.fromString(
            jsonEncode({
              'error': {
                'details': [
                  {'reason': reason},
                ],
              },
            }),
            400,
            headers: {
              'content-type': ['application/json'],
            },
          ),
          streaming: streaming,
        );
        final item = await repo.reply(history).single;
        expect(item.fold((failure) => failure, (_) => null), matcher);
      }
    }
  });

  test(
    'maps transport failures and timeouts without losing the failure type',
    () async {
      for (final (type, matcher) in [
        (DioExceptionType.connectionError, isA<NetworkFailure>()),
        (DioExceptionType.receiveTimeout, isA<TimeoutFailure>()),
      ]) {
        final repo = _repository(
          ProviderProtocol.openAi,
          (options, _) =>
              throw DioException(requestOptions: options, type: type),
        );
        final item = await repo.reply(history).single;
        expect(item.fold((failure) => failure, (_) => null), matcher);
      }
    },
  );

  test('maps auth, rate limit, malformed data and truncated streams', () async {
    for (final (code, matcher) in [
      (401, isA<AuthFailure>()),
      (429, isA<RateLimitFailure>()),
    ]) {
      final repo = _repository(
        ProviderProtocol.openAi,
        (_, _) => ResponseBody.fromString('{}', code),
      );
      expect(
        (await repo.reply(history).single).fold(
          (failure) => failure,
          (_) => null,
        ),
        matcher,
      );
    }
    for (final payload in [
      'data: invalid\n\n',
      'data: {"choices":[{"delta":{"content":"Partial"}}]}\n\n',
    ]) {
      final repo = _repository(
        ProviderProtocol.openAi,
        (_, _) => _sse([payload]),
      );
      final items = await repo.reply(history).toList();
      expect(
        items.last.fold((failure) => failure, (_) => null),
        isA<InvalidResponseFailure>(),
      );
    }
  });
}

ResponseBody _sse(List<String> events) => ResponseBody(
  Stream.fromIterable(
    utf8.encode(events.join()).map((byte) => Uint8List.fromList([byte])),
  ),
  200,
  headers: {
    'content-type': ['text/event-stream'],
  },
);

RemoteChatRepository _repository(
  ProviderProtocol protocol,
  _Response respond, {
  bool streaming = true,
}) {
  final dio = Dio()..httpClientAdapter = _Adapter(respond);
  addTearDown(() => dio.close(force: true));
  return RemoteChatRepository(
    dio,
    LoadProvider(
      _Settings(
        ProviderConfig(
          protocol: protocol,
          name: 'Example',
          baseUrl: 'https://example.test/v1',
          model: 'example',
          apiKey: 'fixture',
          streamReplies: streaming,
        ),
      ),
    ),
  );
}

typedef _Response =
    ResponseBody Function(RequestOptions options, Map<String, dynamic> body);

class _Adapter implements HttpClientAdapter {
  _Adapter(this._response);
  final _Response _response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = await requestStream!.expand((chunk) => chunk).toList();
    return _response(
      options,
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Settings implements SettingsRepository {
  const _Settings(this.config);
  final ProviderConfig config;

  @override
  Future<Either<Failure, ProviderConfig?>> load() async => Right(config);

  @override
  Future<Either<Failure, Unit>> save(ProviderConfig config) async =>
      const Right(unit);
}
