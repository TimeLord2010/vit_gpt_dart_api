import 'dart:io';

import '../enums/audio_model.dart';

abstract class ListenerModel {
  Future<String> listen({
    required File audio,
    required AudioModel model,
    String? language,
    String? prompt,
    double? temperature,
  });
}
