import 'dart:io';

import 'package:vit_gpt_dart_api/data/interfaces/audio_recorder_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/completion_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/local_storage/local_storage_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/tts_model.dart';

import 'interfaces/simple_audio_player_model.dart';
import 'interfaces/threads_model.dart';
import 'interfaces/transcriber_model.dart';

class DynamicFactories {
  static AudioRecorderModel Function()? _recorderFactory;
  static AudioRecorderModel get recorder {
    return _create(_recorderFactory, 'Audio recorder');
  }

  static LocalStorageModel Function()? localStorageFactory;
  static LocalStorageModel get localStorage {
    return _create(localStorageFactory, 'Local Storage');
  }

  static SimpleAudioPlayer Function(File file)? _playerFactory;
  static SimpleAudioPlayer Function(File file) get simplePlayer {
    var fac = _playerFactory;
    if (fac == null) {
      throw Exception('Simple player factory not registered');
    }
    return fac;
  }

  static set simplePlayer(SimpleAudioPlayer Function(File file) fn) {
    _playerFactory = fn;
  }

  static TTSModel Function()? tts;

  static TranscribeModel Function()? transcriber;

  static ThreadsModel Function()? threads;

  static CompletionModel Function(
    String assistantId,
    String threadId,
  )? completionWithAssistant;

  static RealtimeModel Function()? realtime;

  static CompletionModel Function()? completion;
}

T _create<T>(T Function()? fac, String name) {
  if (fac == null) {
    throw Exception('$name factory not registered');
  }
  return fac();
}
