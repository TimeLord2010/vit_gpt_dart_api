import 'dart:convert';
import 'dart:typed_data';

import '../data/enums/gpt_model.dart';
import '../data/enums/sender_type.dart';
import '../data/interfaces/completion_model.dart';
import '../data/models/message.dart';

class CompletionRepository extends CompletionModel {
  final GptModel model;
  final Dio dio;
  final double temperature = 0.7;

  CompletionRepository({
    required this.dio,
    this.model = GptModel.gpt4oMini,
  });

  final url = 'https://api.openai.com/v1/chat/completions';

  @override
  Future<Message> fetch({
    required List<Message> messages,
  }) async {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': messages.map((x) => x.toGptMap).toList(),
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
    required List<Message> messages,
  }) async* {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': messages.map((x) => x.toGptMap).toList(),
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );
    var data = response.data;
    Stream<Uint8List> stream = data.stream;
    String? lastChunk;
    await for (var chunk in stream) {
      var str = utf8.decode(chunk);
      var parts = str.split('\n');
      for (var part in parts) {
        part = part.trim();

        // Concatenating part with last chunk
        if (lastChunk != null) {
          part = lastChunk + part;
          lastChunk = null;
        }

        if (part.isEmpty) {
          continue;
        }
        if (part.startsWith('data: ')) {
          part = part.substring(6);
        }
        if (part == '[DONE]') {
          continue;
        }
        try {
          var map = jsonDecode(part);
          List choices = map['choices'];
          Map<String, dynamic> choice = choices[0];
          Map<String, dynamic> delta = choice['delta'];
          String? content = delta['content'];
          if (content != null) {
            yield content;
          }
        } on FormatException {
          // Failed to parse json. Must be only part of the json.
          lastChunk = part;
        }
      }
    }
  }
}
