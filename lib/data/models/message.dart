import '../enums/sender_type.dart';

class Message {
  String? messageId;
  final DateTime date;
  String text;
  final SenderType sender;

  Message({
    this.messageId,
    required this.date,
    required this.text,
    required this.sender,
  });

  factory Message.user({
    required String message,
  }) {
    return Message(
      date: DateTime.now(),
      text: message,
      sender: SenderType.user,
    );
  }

  factory Message.assistant({
    required String message,
  }) {
    return Message(
      date: DateTime.now(),
      text: message,
      sender: SenderType.assistant,
    );
  }

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
    );
  }

  Map<String, dynamic> get toGptMap {
    return {
      'role': sender == SenderType.user ? 'user' : 'assistant',
      'content': text,
    };
  }
}
