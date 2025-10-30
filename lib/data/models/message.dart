import 'dart:convert';

import 'package:vit_gpt_dart_api/data/models/realtime_events/usage.dart';

import '../enums/role.dart';

class Message {
  String? id;
  DateTime date;
  String text;
  final Role role;
  final Usage? usage;
  final List<int>? audio;

  Message({
    this.id,
    required this.date,
    required this.text,
    required this.role,
    this.audio,
    this.usage,
  });

  factory Message.user({
    required String message,
    DateTime? date,
  }) {
    return Message(
      date: date ?? DateTime.now(),
      text: message,
      role: Role.user,
    );
  }

  factory Message.assistant({
    required String message,
    Usage? usage,
    List<int>? audio,
    DateTime? date,
  }) {
    return Message(
      date: date ?? DateTime.now(),
      text: message,
      role: Role.assistant,
      usage: usage,
      audio: audio,
    );
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    String? roleStr = map['role'];

    if (roleStr == null) {
      throw Exception("Invalid message json: ${map}");
    } 

    DateTime getDate() {
      /// Open ai sends "created_at" as a integer as Epoch milliseconds,
      /// but some other systems could send the value as a ISO string or
      /// in the "created" map key.
      var createdAt = map['date'] ??
          map['created_at'] ??
          map['createdAt'] ??
          map['created'];
      if (createdAt is num) {
        return DateTime.fromMillisecondsSinceEpoch(createdAt.toInt()).toLocal();
      }
      if (createdAt is String) {
        return DateTime.parse(createdAt).toLocal();
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

    var role = roleStr == 'user' ? Role.user : Role.assistant;
    Map<String, dynamic>? usage = map['usage'];

    return Message(
      id: map['id'],
      date: getDate(),
      text: getText(),
      role: role,
      usage: usage == null ? null : Usage.fromMap(usage),
      audio: null,
      // TODO
      // map['audio'] != null && map['audio'].isNotEmpty
      //     ? base64Decode(map['audio'])
      //     : null,
    );
  }

  Map<String, dynamic> get toGptMap {
    return {
      'role': role == Role.user ? 'user' : 'assistant',
      'contentt': text,
      'audio': audio != null && audio!.isNotEmpty ? base64Encode(audio!) : null,
    };
  }
}
