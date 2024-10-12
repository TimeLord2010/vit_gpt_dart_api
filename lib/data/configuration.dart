import 'dart:io';

import 'package:vit_gpt_dart_api/data/enums/audio_format.dart';

class VitGptConfiguration {
  static Directory? _internalFilesDirectory;
  static Directory get internalFilesDirectory {
    var dir = _internalFilesDirectory;
    if (dir == null) {
      throw Exception('Not initialized: internal files directory');
    }
    return dir;
  }

  static set internalFilesDirectory(Directory directory) {
    _internalFilesDirectory = directory;
  }

  static bool useHighQualityTts = false;

  static AudioFormat ttsFormat = AudioFormat.opus;

  static String transcriptionLanguage = 'pt';
}
