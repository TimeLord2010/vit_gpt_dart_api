import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/data/errors/completion_exception.dart';
import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/factories/logger.dart';
import 'package:vit_gpt_dart_api/usecases/http/get_json_stream_from_response.dart';
import 'package:vit_gpt_dart_api/usecases/http/read_message_chunk.dart';

import '../data/interfaces/completion_model.dart';

class AssistantRepository extends CompletionModel {
  final String assistantId, threadId;
  final Dio dio;

  AssistantRepository({
    required this.dio,
    required this.assistantId,
    required this.threadId,
  });

  String get url => 'https://api.openai.com/v1/threads/$threadId/runs';

  @override
  Future<Message> fetch({
    List<Message>? previousMessages,
  }) {
    // TODO: implement fetch
    throw UnimplementedError();
  }

  @override
  Stream<String> fetchStream({
    List<Message>? previousMessages,
    int retries = 2,
    FutureOr<void> Function(
      CompletionException error,
      int retriesRemaning,
    )? onError,
    void Function(Map<String, dynamic> chunk)? onJsonComplete,
  }) async* {
    // Creating run
    Response response = await dio.post(
      url,
      data: {
        'assistant_id': assistantId,
        'stream': true,
        if (previousMessages != null)
          'additional_messages': previousMessages.map((x) {
            return x.toGptMap;
          }).toList(),
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );
    var stream = getJsonStreamFromResponse(response, ignorePrefixes: {
      'event',
    });

    // Reading stream
    await for (var part in stream) {
      if (onJsonComplete != null) onJsonComplete(part);
      String object = part['object'];
      if (object == 'chat.completion.chunk') {
        var content = readMessageChunk(part);
        if (content != null) {
          yield content;
        }
      } else if (object == 'thread.message.delta') {
        // Handling new messages
        Map<String, dynamic> delta = part['delta'];
        List content = delta['content'];
        Map<String, dynamic> item = content.first;
        String type = item['type'];
        if (type == 'text') {
          Map<String, dynamic> text = item['text'];
          String value = text['value'];
          yield value;
        } else {
          logger.warn('Unable to process type: $type');
        }
      } else if (object == 'thread.run.step') {
        // Handling errors
        Map<String, dynamic>? lastError = part['last_error'];
        if (lastError == null) {
          continue;
        }
        String? errorCode = part['code'];
        String? errorMessage = part['message'];
        var exception = CompletionException(errorCode, errorMessage);
        if (onError != null) await onError(exception, retries);
        if (retries <= 0) throw exception;
        await Future.delayed(Duration(seconds: 1));
        var retryStream = fetchStream(
          retries: retries - 1,
        );
        yield* retryStream;
      }
    }
  }

  @override
  bool get addsResponseAutomatically => true;

  @override
  bool get addsPreviousMessagesToThread => true;
}
