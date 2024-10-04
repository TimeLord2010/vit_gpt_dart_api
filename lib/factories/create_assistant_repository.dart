import 'package:vit_gpt_dart_api/data/interfaces/assistant_model.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/repositories/assistant_repository.dart';

AssistantModel createAssistantRepository(String assistantId) {
  return AssistantRepository(
    dio: httpClient,
    assistantId: assistantId,
  );
}
