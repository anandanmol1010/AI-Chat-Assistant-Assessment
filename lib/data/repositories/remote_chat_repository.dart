import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/provider_settings.dart';
import '../datasources/ai_provider.dart';
import '../datasources/sse.dart';

class RemoteChatRepository implements ChatRepository {
  const RemoteChatRepository(this._dio, this._loadProvider);

  final Dio _dio;
  final LoadProvider _loadProvider;

  @override
  Stream<Either<Failure, String>> reply(List<Message> history) async* {
    final settings = await _loadProvider();
    final failure = settings.fold<Failure?>((failure) => failure, (_) => null);
    if (failure != null) {
      yield Left(failure);
      return;
    }
    final config = settings.getOrElse((_) => null);
    final configError = config?.validationError;
    if (config == null || configError != null) {
      yield Left(
        ConfigFailure(configError ?? 'Set up a provider before sending.'),
      );
      return;
    }
    final AiProvider provider = config.protocol == ProviderProtocol.gemini
        ? const GeminiProvider()
        : const OpenAiCompatibleProvider();
    final request = provider.request(config, history);

    try {
      final response = await _dio.post<Object?>(
        request.endpoint,
        data: request.body,
        options: Options(
          headers: request.headers,
          responseType: config.streamReplies
              ? ResponseType.stream
              : ResponseType.json,
          followRedirects: false,
        ),
      );
      final body = response.data;
      if (body is ResponseBody) {
        var hasText = false;
        await for (final data in sseData(body.stream)) {
          if (data == '[DONE]') {
            if (hasText) return;
            break;
          }
          final chunk = provider.decode(
            jsonDecode(data) as Map<String, dynamic>,
            streaming: true,
          );
          if (chunk.text.isNotEmpty) {
            hasText |= chunk.text.trim().isNotEmpty;
            yield Right(chunk.text);
          }
          if (chunk.finished) {
            if (hasText) return;
            break;
          }
        }
        yield const Left(InvalidResponseFailure());
      } else {
        final json = body is String ? jsonDecode(body) : body;
        final chunk = provider.decode(
          json as Map<String, dynamic>,
          streaming: false,
        );
        yield chunk.text.trim().isEmpty
            ? const Left(InvalidResponseFailure())
            : Right(chunk.text);
      }
    } on DioException catch (error) {
      yield Left(_mapDioError(error));
    } on TimeoutException {
      yield const Left(TimeoutFailure());
    } on SocketException {
      yield const Left(NetworkFailure());
    } on FormatException {
      yield const Left(InvalidResponseFailure());
    } on TypeError {
      yield const Left(InvalidResponseFailure());
    } on StateError {
      yield const Left(InvalidResponseFailure());
    }
  }

  Failure _mapDioError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) return const AuthFailure();
    if (status == 429) return const RateLimitFailure();
    if (status != null && status >= 500) return const ServerFailure();
    if (status == 400 || status == 404) {
      return const ConfigFailure(
        'The provider rejected this request. Check the API key, URL, and model.',
      );
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const TimeoutFailure(),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => const NetworkFailure(),
      DioExceptionType.unknown when error.error is SocketException =>
        const NetworkFailure(),
      _ => const InvalidResponseFailure(),
    };
  }
}
