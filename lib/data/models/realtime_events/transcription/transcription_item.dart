import 'package:vit_gpt_dart_api/data/enums/role.dart';

/// A chunk of transcription data of the user or ai.
///
/// Meaning the same id will appear multiple times until one is completed.
class TranscriptionItem {
  final String id;
  final String text;
  final Role role;

  TranscriptionItem({
    required this.id,
    required this.text,
    required this.role,
  });
}
