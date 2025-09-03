import 'package:vit_gpt_dart_api/data/enums/role.dart';

/// A chunk of transcription data of the user or ai.
///
/// Meaning the same id will appear multiple times until one is completed.
class TranscriptionItem {
  String? itemId;
  String? eventId;
  String? responseId;
  String text;
  Role role;
  int? outputIndex;
  int? contentIndex;

  TranscriptionItem({
    required this.itemId,
    required this.eventId,
    required this.responseId,
    required this.text,
    required this.role,
    required this.contentIndex,
    required this.outputIndex,
  });

  factory TranscriptionItem.fromMap(
    Map<String, dynamic> map, {
    required Role role,
  }) {
    return TranscriptionItem(
      itemId: map['item_id'],
      eventId: map['event_id'],
      responseId: map['response_id'],
      text: map['delta'],
      role: role,
      contentIndex: (map['content_index'] as num?)?.toInt(),
      outputIndex: (map['output_index'] as num?)?.toInt(),
    );
  }
}
