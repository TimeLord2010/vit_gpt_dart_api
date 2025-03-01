import '../enums/role.dart';

class Message {
  String? id;
  final DateTime date;
  String text;
  final Role role;

  Message({
    this.id,
    required this.date,
    required this.text,
    required this.role,
  });

  factory Message.user({
    required String message,
  }) {
    return Message(
      date: DateTime.now(),
      text: message,
      role: Role.user,
    );
  }

  factory Message.assistant({
    required String message,
  }) {
    return Message(
      date: DateTime.now(),
      text: message,
      role: Role.assistant,
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
      role: role == 'user' ? Role.user : Role.assistant,
    );
  }

  Map<String, dynamic> get toGptMap {
    return {
      'role': role == Role.user ? 'user' : 'assistant',
      'content': text,
    };
  }
}
