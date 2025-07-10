import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_message.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/usage.dart';

enum RealtimeResponseStatus {
  completed,
  cancelled,
  failed,
  incomplete;

  factory RealtimeResponseStatus.fromValue(String value) {
    return switch (value) {
      'completed' => completed,
      'cancelled' => cancelled,
      'incomplete' => incomplete,
      _ => failed,
    };
  }
}

class RealtimeResponse {
  final String id;
  final RealtimeResponseStatus status;
  final Map<String, dynamic>? statusDetails;
  final List<RealtimeMessage> output;
  final Usage usage;

  RealtimeResponse({
    required this.id,
    required this.status,
    required this.output,
    required this.usage,
    this.statusDetails,
  });

  factory RealtimeResponse.fromMap(Map<String, dynamic> map) {
    return RealtimeResponse(
      id: map['id'],
      status: RealtimeResponseStatus.fromValue(map['status']),
      output: map.getList('output', (x) => RealtimeMessage.fromMap(x)),
      usage: Usage.fromMap(map['usage']),
    );
  }
}
