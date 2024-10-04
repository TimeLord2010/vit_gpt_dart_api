import 'package:vit_gpt_dart_api/factories/create_assistant_repository.dart';

Stream<String> askAssistant({
  required String assistantId,
  required String threadId,
}) {
  var rep = createAssistantRepository(assistantId);
  var messageStream = rep.complete(threadId);
  return messageStream;
}
