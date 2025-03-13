import '../models/conversation.dart';
import '../models/message.dart';

abstract class ThreadsModel {
  Future<Conversation> load(String id);

  Future<Conversation> create([List<Message>? messages]);

  Future<void> delete(String id);

  Future<List<Message>> listMessages({
    required String threadId,
    bool? asc,
    int? limit,
    String? after,
    String? before,
  });

  Future<Message> createMessage(String threadId, Message message);

  Future<void> deleteMessage(String threadId, String messageId);

  Future<void> saveMetadata(String threadId, Map<String, String> metadata);
}
