import '../enums/sender_type.dart';

class Message {
  String? messageId;
  String? threadId;
  final DateTime date;
  String text;
  final SenderType sender;

  Message({
    this.messageId,
    required this.date,
    required this.text,
    required this.sender,
    this.threadId,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    String role = map['role'];
    int createdAt = map['created_at'];
    List content = map['content'];
    String getText() {
      for (Map item in content) {
        String type = item['type'];
        if (type == 'text') {
          Map text = item['text'];
          //List annotations = item['annotations'];
          return text['value'];
        }
      }
      return 'NOT IMPLEMENTED';
    }

    return Message(
      date: DateTime.fromMillisecondsSinceEpoch(createdAt),
      text: getText(),
      sender: role == 'user' ? SenderType.user : SenderType.assistant,
      threadId: map['thread_id'],
    );
  }

  Map<String, dynamic> get toGptMap {
    return {
      'role': sender == SenderType.user ? 'user' : 'assistant',
      'content': text,
    };
  }
}
