import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/data/interfaces/assistants_model.dart';
import 'package:vit_gpt_dart_api/data/models/assistant.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';

class AssistantsRepository extends AssistantsModel {
  @override
  Future<List<Assistant>> findAssistants() async {
    var url = 'https://api.openai.com/v1/assistants';
    var response = await httpClient.get(url);
    Map<String, dynamic> map = response.data;
    var list = map.getList('data', (item) => Assistant.fromMap(item));
    return list;
  }
}
