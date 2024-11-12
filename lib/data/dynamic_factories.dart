import 'dart:io';

import 'package:vit_gpt_dart_api/data/interfaces/audio_recorder_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/local_storage/local_storage_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/tts_model.dart';

import 'interfaces/simple_audio_player_model.dart';

class DynamicFactories {
  static AudioRecorderModel Function()? _recorderFactory;
  static AudioRecorderModel get recorder {
    return _create(_recorderFactory, 'Audio recorder');
  }

  static LocalStorageModel Function()? _localStorageFactory;
  static LocalStorageModel get localStorage {
    return _create(_localStorageFactory, 'Local Storage');
  }

  static TTSModel Function()? tts;

  static SimpleAudioPlayer Function(File file)? _playerFactory;
  static SimpleAudioPlayer Function(File file) get simplePlayerFactory {
    var fac = _playerFactory;
    if (fac == null) {
      throw Exception('Simple player factory not registered');
    }
    return fac;
  }
}

T _create<T>(T Function()? fac, String name) {
  if (fac == null) {
    throw Exception('$name factory not registered');
  }
  return fac();
}

/// Sets up the factories for components that required them. Such as
/// classes or methods needing the recorder to have been set.
///
/// If you don't use components that require a factory, you don't need to set
/// it up.
///
/// [localStorage] is required by many usecases so you may set a factory
/// for it.
void setupFactories({
  AudioRecorderModel Function()? recorder,
  LocalStorageModel Function()? localStorage,
  TTSModel Function()? tts,
  SimpleAudioPlayer Function(File file)? simplePlayerFactory,
}) {
  DynamicFactories._recorderFactory = recorder;
  DynamicFactories._localStorageFactory = localStorage;
  DynamicFactories._playerFactory = simplePlayerFactory;
  DynamicFactories.tts = tts;
}
