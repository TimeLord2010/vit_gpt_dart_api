import '../models/message.dart';

abstract class CompletionModel {
  Future<Message> fetch({
    required List<Message> messages,
  });

  Stream<String> fetchStream({
    required List<Message> messages,
  });
}
