import 'package:vit_gpt_dart_api/data/enums/role.dart';

class TranscriptionEnd {
  final String id;
  final Role role;

  TranscriptionEnd({
    required this.id,
    required this.role,
  });
}
