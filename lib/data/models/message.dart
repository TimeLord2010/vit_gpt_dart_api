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

    DateTime getDate() {
      /// Open ai sends "created_at" as a integer as Epoch milliseconds,
      /// but some other systems could send the value as a ISO string or
      /// in the "created" map key.
      var createdAt = map['created_at'] ?? map['created'];
      if (createdAt is num) {
        return DateTime.fromMillisecondsSinceEpoch(createdAt.toInt());
      }
      if (createdAt is String) {
        return DateTime.parse(createdAt);
      }

      return DateTime.now();
    }

    String getText() {
      var content = map['content'];

      if (content is String) {
        return content;
      }

      /// Open AI message structure
      if (content is List) {
        for (Map item in content) {
          String type = item['type'];
          if (type == 'text') {
            Map text = item['text'];
            //List annotations = item['annotations'];
            return text['value'];
          }
        }
      }
      return 'NOT IMPLEMENTED';
    }

    return Message(
      date: getDate(),
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
