import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/usecases/http/get_json_stream_from_response.dart';

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
    var stream = getJsonStreamFromResponse(response);
    await for (var json in stream) {
      List choices = json['choices'];
      Map<String, dynamic> choice = choices[0];
      Map<String, dynamic> delta = choice['delta'];
      String? content = delta['content'];
      if (content != null) {
        yield content;
      }
    }
  }
}
