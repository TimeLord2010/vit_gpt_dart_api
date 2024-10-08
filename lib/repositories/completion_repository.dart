import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/usecases/http/get_json_stream_from_response.dart';

import '../data/enums/gpt_model.dart';
import '../data/enums/sender_type.dart';
import '../data/interfaces/completion_model.dart';
import '../data/models/message.dart';

class CompletionRepository extends CompletionModel {
  final GptModel model;
  final Dio dio;
  double temperature = 0.7;
  List<Message> _messages = [];

  CompletionRepository({
    required this.dio,
    required List<Message> messages,
    this.model = GptModel.gpt4oMini,
  }) {
    _messages.addAll(messages);
    if (_messages.length > amountToSend) {
      _messages = _messages.skip(_messages.length - amountToSend).toList();
    }
  }

  final url = 'https://api.openai.com/v1/chat/completions';

  /// Amount of messages to send.
  static int amountToSend = 15;

  @override
  Future<Message> fetch() async {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': _messages.map((x) => x.toGptMap).toList(),
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
  Stream<String> fetchStream() async* {
    var response = await dio.post(
      url,
      data: {
        'model': model.toString(),
        'messages': _messages.map((x) => x.toGptMap).toList(),
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );

    // Fetches the content of the message
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
