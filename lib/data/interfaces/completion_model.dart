import '../models/message.dart';

abstract class CompletionModel {
  Future<Message> fetch();

  Stream<String> fetchStream();
}
