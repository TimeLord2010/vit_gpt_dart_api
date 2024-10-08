import 'package:dio/dio.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';
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
  Future<Message> fetch() {
    // TODO: implement fetch
    throw UnimplementedError();
  }

  @override
  Stream<String> fetchStream() async* {
    Response response = await httpClient.post(
      url,
      data: {
        'assistant_id': assistantId,
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );
    var stream = getJsonStreamFromResponse(response, ignorePrefixes: {
      'event',
    });

    await for (var part in stream) {
      logger.info('Part: ${part.prettyJSON}');
      String object = part['object'];
      if (object == 'chat.completion.chunk') {
        var content = readMessageChunk(part);
        if (content != null) {
          yield content;
        }
      } else if (object == 'thread.message.delta') {
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
      }
    }
  }
}
