abstract class AssistantModel {
  String get assistantId;

  Stream<String> complete(
    String threadId, {
    String? model,
  });
}
