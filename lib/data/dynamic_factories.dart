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
  static AudioRecorderModel Function()? recorder;

  static LocalStorageModel Function()? localStorage;

  static SimpleAudioPlayer Function(File file)? simplePlayer;

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
