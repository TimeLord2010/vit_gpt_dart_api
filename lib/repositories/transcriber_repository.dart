import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:vit_gpt_dart_api/usecases/audio/get_audio_intensity_from_decibel.dart';

import '../data/enums/audio_model.dart';
import '../data/interfaces/transcriber_model.dart';
import 'handlers/voice_recorder_handler.dart';

class TranscriberRepository extends TranscribeModel {
  final Dio _dio;
  final AudioModel model;
  final String? prompt;
  final double? temperature;
  final String? language;

  TranscriberRepository({
    required Dio dio,
    required this.model,
    this.prompt,
    this.language,
    this.temperature,
  }) : _dio = dio;

  final voiceRecorder = VoiceRecorderHandler();

  var _streamController = StreamController<String>();

  @override
  Future<void> endTranscription() async {
    if (!voiceRecorder.isRecording) {
      return;
    }
    var file = await voiceRecorder.stop();
    var transcription = await transcribeFromFile(file);
    _streamController.add(transcription);
    _streamController.close();
    _streamController = StreamController<String>();
  }

  @override
  Future<void> startTranscribe() async {
    if (voiceRecorder.isRecording) {
      return;
    }
    await voiceRecorder.start();
  }

  @override
  Stream<String> get transcribed => _streamController.stream;

  @override
  void dispose() {
    _streamController.close();
    voiceRecorder.dispose();
  }

  @override
  Future<String> transcribeFromFile(File file) async {
    var url = 'https://api.openai.com/v1/audio/transcriptions';
    var form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'model': model.toString(),
      if (language != null) 'language': language,
      if (prompt != null) 'prompt': prompt,
      if (temperature != null) 'temperature': temperature,
    });
    var response = await _dio.post(
      url,
      data: form,
    );
    Map<String, dynamic> map = response.data;
    String text = map['text'];
    return text;
  }

  @override
  Stream<double> get onMicVolumeChange {
    return voiceRecorder.rawAmplitudes.map((x) {
      return getAudioIntensityFromDecibel(value: x);
    });
  }

  @override
  Stream<bool> get onSilenceChange {
    if (!voiceRecorder.enableSilenceDetection) {
      return Stream.empty();
    }
    return voiceRecorder.silenceStream;
  }
}
