import 'dart:io';

import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/enums/audio_format.dart';

class VitGptDartConfiguration {
  static Directory? _internalFilesDirectory;

  /// Folder used to store files such as TTS files.
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

  static Level logLevel = Level.all;
}
