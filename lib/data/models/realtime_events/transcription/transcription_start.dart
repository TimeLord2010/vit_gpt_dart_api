import 'package:vit_gpt_dart_api/data/enums/role.dart';

class TranscriptionStart {
  final String id;
  final Role role;

  TranscriptionStart({
    required this.id,
    required this.role,
  });
}
