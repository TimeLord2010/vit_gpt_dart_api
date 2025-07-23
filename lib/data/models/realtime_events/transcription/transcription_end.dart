import 'package:vit_gpt_dart_api/data/enums/role.dart';

class TranscriptionEnd {
  final String id;
  final Role role;
  final String content;
  final DateTime? createdAt;

  TranscriptionEnd({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt
  });
}
