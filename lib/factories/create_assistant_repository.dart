import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/repositories/assistant_repository.dart';

import '../data/dynamic_factories.dart';
import '../data/interfaces/completion_model.dart';

CompletionModel createAssistantRepository(
  String assistantId,
  String threadId,
) {
  var fac = DynamicFactories.assistantRepository;
  if (fac != null) {
    return fac(assistantId, threadId);
  }

  return AssistantRepository(
    dio: httpClient,
    assistantId: assistantId,
    threadId: threadId,
  );
}
