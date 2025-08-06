import 'package:vit_gpt_dart_api/data/enums/role.dart';

class SpeechEnd {
  final String id;
  final Role role;
  final bool done;

  SpeechEnd({
    required this.id,
    required this.role,
    required this.done,
  });
}
