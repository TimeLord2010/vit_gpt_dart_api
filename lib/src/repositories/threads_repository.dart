import '../data/interfaces/threads_model.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../factories/http_client.dart';

class ThreadsRepository extends ThreadsModel {
  @override
  Future<Conversation> create([List<Message>? messages]) async {
    var payload = {
      if (messages != null)
        'messages': messages.map((x) => x.toGptMap).toList(),
    };
    var response = await httpClient.post(
      'https://api.openai.com/v1/threads',
      data: payload,
    );
    Map<String, dynamic> data = response.data;
    return Conversation.fromMap(data);
  }

  @override
  Future<void> delete(String id) async {
    var url = 'https://api.openai.com/v1/threads/$id';
    await httpClient.delete(url);
  }

  @override
  Future<Conversation> load(String id) async {
    var url = 'https://api.openai.com/v1/threads/$id';
    var response = await httpClient.get(url);
    Map<String, dynamic> data = response.data;
    return Conversation.fromMap(data);
  }

  @override
  Future<List<Message>> listMessages({
    required String threadId,
    bool? asc,
    int? limit,
    String? after,
    String? before,
  }) async {
    var url = 'https://api.openai.com/v1/threads/$threadId/messages';
    var response = await httpClient.get(
      url,
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (asc != null) 'order': asc ? 'asc' : 'desc',
        if (after != null) 'after': after,
        if (before != null) 'before': before,
      },
    );
    Map data = response.data;
    List list = data['data'];
    //bool hasMore = data['has_more'];

    Iterable<Message> messages = list.map((x) {
      Map<String, dynamic> map = x;
      return Message.fromMap(map);
    });

    return messages.toList();
  }

  @override
  Future<Message> sendMessage(String threadId, Message message) async {
    var url = 'https://api.openai.com/v1/threads/$threadId/messages';
    var response = await httpClient.post(
      url,
      data: message.toGptMap,
    );
    Map<String, dynamic> data = response.data;
    var newMessage = Message.fromMap(data);
    message.messageId = newMessage.messageId;
    message.threadId = newMessage.threadId;
    return newMessage;
  }

  @override
  Future<void> deleteMessage(String threadId, String messageId) async {
    var url = 'https://api.openai.com/v1/threads/$threadId/messages/$messageId';
    await httpClient.delete(url);
  }

  @override
  Future<void> saveMetadata(
    String threadId,
    Map<String, String> metadata,
  ) async {
    var url = 'https://api.openai.com/v1/threads/$threadId';
    await httpClient.post(url, data: {
      'metadata': metadata,
    });
  }
}
