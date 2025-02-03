import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/data/errors/completion_exception.dart';
import 'package:vit_gpt_dart_api/usecases/http/get_json_stream_from_response.dart';
import 'package:vit_gpt_dart_api/usecases/http/read_message_chunk.dart';

import '../data/enums/gpt_model.dart';
import '../data/enums/sender_type.dart';
import '../data/interfaces/completion_model.dart';
import '../data/models/message.dart';

class CompletionRepository extends CompletionModel {
  final GptModel model;
  final Dio dio;
  double temperature = 0.7;

  CompletionRepository({
    required this.dio,
    this.model = GptModel.gpt4oMini,
  });

  final url = 'https://api.openai.com/v1/chat/completions';

  /// Amount of messages to send.
  static int amountToSend = 30;

  List<Map<String, dynamic>> _getMessages(List<Message>? previousMessages) {
    Iterable<Message>? messages = previousMessages;
    if (messages == null) throw Exception('Previous messages are required');
    if (messages.isEmpty) {
      throw Exception('Empty messages in the conversation');
    }

    messages = messages.where((x) => x.text.isNotEmpty);

    if (messages.length > amountToSend) {
      messages = messages.skip(messages.length - amountToSend);
    }

    return messages.map((x) => x.toGptMap).toList();
  }

  @override
  Future<Message> fetch({
    List<Message>? previousMessages,
  }) async {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': _getMessages(previousMessages),
      },
    );
    Map<String, dynamic> data = response.data;
    int created = data['created'];
    List choices = data['choices'];
    if (choices.length > 1) {
      throw Exception('Multiple choices');
    }
    Map<String, dynamic> choice = choices.first;
    return Message(
      messageId: data['id'],
      date: DateTime.fromMillisecondsSinceEpoch(created),
      text: choice['message']['content'],
      sender: SenderType.assistant,
    );
  }

  @override
  Stream<String> fetchStream({
    List<Message>? previousMessages,
    int retries = 2,
    FutureOr<void> Function(CompletionException error, int retriesRemaning)?
        onError,
    void Function(Map<String, dynamic> chunk)? onJsonComplete,
  }) async* {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': _getMessages(previousMessages),
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );

    // Fetches the content of the message
    var stream = getJsonStreamFromResponse(response);
    await for (var json in stream) {
      if (onJsonComplete != null) onJsonComplete(json);
      var content = readMessageChunk(json);
      if (content != null) {
        yield content;
      }
    }
  }

  @override
  bool get addsResponseAutomatically => false;

  @override
  bool get addsPreviousMessagesToThread => false;
}
