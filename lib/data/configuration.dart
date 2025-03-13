import 'dart:io';

import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/enums/audio_format.dart';
import 'package:vit_gpt_dart_api/factories/create_log_group.dart';

class VitGptConfiguration {
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

  static Level _level = Level.all;
  static Level get logLevel => _level;
  static set logLevel(Level level) {
    _level = level;
    logger = Logger(
      printer: SimplePrinter(),
      level: level,
    );
  }

  static var logger = Logger(
    //filter: AlwaysLogFilter(),
    printer: SimplePrinter(),
  );

  static Logger Function(List<String> tags) createLogGroup = createLogger;
}

// use this to enable logs on profile or release mode
// class AlwaysLogFilter extends LogFilter {
//   @override
//   bool shouldLog(LogEvent event) => true;
// }
