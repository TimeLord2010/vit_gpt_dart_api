import 'package:vit_gpt_dart_api/data/enums/role.dart';

class SpeechStart {
  final String id;
  final Role role;

  SpeechStart({
    required this.id,
    required this.role,
  });
}
