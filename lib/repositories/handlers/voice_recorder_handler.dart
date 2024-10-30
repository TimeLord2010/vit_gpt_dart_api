import 'dart:io';

import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';
import 'package:vit_gpt_dart_api/data/interfaces/audio_recorder_model.dart';
import 'package:vit_gpt_dart_api/factories/logger.dart';
import 'package:vit_gpt_dart_api/repositories/handlers/silence_detector.dart';

class VoiceRecorderHandler {
  AudioRecorderModel? _recorder;
  SilenceDetector? silenceDetector;
  Stream<double>? _rawAudioStream;
  bool isRecording = false;

  AudioRecorderModel get recorder {
    _recorder ??= DynamicFactories.recorder;
    return _recorder!;
  }

  Future<double> get amplitude async => recorder.amplitude;

  Future<void> dispose() async {
    _rawAudioStream = null;

    silenceDetector?.dispose();
    silenceDetector = null;

    await _recorder?.dispose();
    _recorder = null;

    isRecording = false;
  }

  Stream<double> get rawAmplitudes {
    return _rawAudioStream!;
  }

  Stream<double> onAmplitudes() => recorder.onAmplitude();

  Stream<bool> get silenceStream {
    var stream = silenceDetector?.stream;
    if (stream == null) {
      logger.error('Failed to get silence stream');
      return Stream.empty();
    }
    return stream;
  }

  /// Starts the audio recording.
  ///
  /// This method will return false if the platform does not have the required
  /// permission.
  Future<bool> start() async {
    // Check and request permission if needed
    var hasPermission = await recorder.requestPermission();
    if (!hasPermission) {
      return false;
    }

    // Start recording to file
    await recorder.start();
    _rawAudioStream = recorder.onRawAmplitude().asBroadcastStream();
    silenceDetector = SilenceDetector(
      decibelsStream: _rawAudioStream!,
    );

    isRecording = true;
    return true;
  }

  /// Stops the audio recorder.
  ///
  /// Throws a [StateError] if the recorder is not active.
  Future<File> stop() async {
    String? path = await recorder.stop();
    if (path == null) {
      throw StateError('Was not recording to stop');
    }

    dispose();

    return File(path);
  }
}
