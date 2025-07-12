import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/data/enums/role.dart';

enum RealtimeMessageStatus {
  completed,
  incomplete;

  factory RealtimeMessageStatus.fromValue(String value) {
    return switch (value) {
      'completed' => completed,
      _ => incomplete,
    };
  }
}

class RealtimeMessageContent {
  final String? transcript, text, audio;

  RealtimeMessageContent({
    this.text,
    this.transcript,
    this.audio,
  });

  factory RealtimeMessageContent.fromMap(Map<String, dynamic> map) {
    return RealtimeMessageContent(
      text: map['text'] ?? map['input_text'],
      transcript: map['transcript'],
      audio: map['input_audio'],
    );
  }
}

class RealtimeMessage {
  final String id;
  final RealtimeMessageStatus status;
  final Role role;
  final List<RealtimeMessageContent> content;

  RealtimeMessage({
    required this.id,
    required this.status,
    required this.role,
    required this.content,
  });

  factory RealtimeMessage.fromMap(Map<String, dynamic> map) {
    return RealtimeMessage(
      id: map['id'],
      status: RealtimeMessageStatus.fromValue(map['status']),
      role: Role.fromValue(map['role']),
      content: map.getList('content', (x) => RealtimeMessageContent.fromMap(x)),
    );
  }
}
