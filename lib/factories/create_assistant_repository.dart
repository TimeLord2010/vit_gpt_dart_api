import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/repositories/assistant_repository.dart';

import '../data/interfaces/completion_model.dart';

CompletionModel createAssistantRepository(
  String assistantId,
  String threadId,
) {
  return AssistantRepository(
    dio: httpClient,
    assistantId: assistantId,
    threadId: threadId,
  );
}
