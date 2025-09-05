import 'package:vit_gpt_dart_api/data/enums/role.dart';

class TranscriptionEnd {
  final String id;
  final Role role;
  final String content;
  final int contentIndex;
  final int? outputIndex;

  const TranscriptionEnd({
    required this.id,
    required this.role,
    required this.content,
    required this.contentIndex,
    this.outputIndex,
  });

  @override
  String toString() {
    return 'TranscriptionEnd(role: $role, contentIndex: $contentIndex, content: $content)';
  }
}
