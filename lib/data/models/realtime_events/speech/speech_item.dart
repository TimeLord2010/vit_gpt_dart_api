import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/enums/role.dart';

class SpeechItem<T> {
  final String id;
  final Role role;
  final T audioData;

  SpeechItem({
    required this.id,
    required this.role,
    required this.audioData,
  });

  Uint8List get bytes {
    var data = audioData;

    if (data is Uint8List) {
      return data;
    }

    if (data is String) {
      return base64Decode(data);
    }

    throw Exception('Invalid audio data type');
  }
}
