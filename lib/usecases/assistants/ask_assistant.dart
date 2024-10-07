import 'package:vit_gpt_dart_api/factories/create_assistant_repository.dart';

Stream<String> askAssistant({
  required String assistantId,
  required String threadId,
}) {
  var rep = createAssistantRepository(assistantId, threadId);
  var messageStream = rep.fetchStream();
  return messageStream;
}
