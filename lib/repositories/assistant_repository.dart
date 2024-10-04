import 'package:dio/dio.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/data/interfaces/assistant_model.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/factories/logger.dart';
import 'package:vit_gpt_dart_api/usecases/http/get_json_stream_from_response.dart';

class AssistantRepository extends AssistantModel {
  final String _assistantId;
  final Dio dio;

  AssistantRepository({
    required this.dio,
    required String assistantId,
  }) : _assistantId = assistantId;

  @override
  String get assistantId => _assistantId;

  @override
  Stream<String> complete(
    String threadId, {
    String? model,
  }) async* {
    String url = 'https://api.openai.com/v1/threads/$threadId/runs';
    Response response = await httpClient.post(
      url,
      options: Options(
        responseType: ResponseType.stream,
      ),
    );
    var stream = getJsonStreamFromResponse(response, ignorePrefixes: {
      'event',
    });

    await for (var part in stream) {
      logger.info('Part: ${part.prettyJSON}');
    }
  }
}
