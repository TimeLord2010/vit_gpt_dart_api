import 'dart:io';

import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';
import 'package:vit_gpt_dart_api/repositories/handlers/silence_detector.dart';

class VoiceRecorderHandler {
  final recorder = DynamicFactories.recorder;
  SilenceDetector? _silenceDetector;
  Stream<double>? _rawAudioStream;

  bool isRecording = false;

  Future<double> get amplitude async => recorder.amplitude;

  Future<void> dispose() async {
    isRecording = false;
    await recorder.dispose();
  }

  Stream<double> get rawAmplitudes {
    return _rawAudioStream!;
  }

  Stream<double> onAmplitudes() {
    return recorder.onAmplitude();
  }

  Stream<bool> get silenceStream {
    return _silenceDetector?.silenceController.stream ?? Stream.empty();
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
    _silenceDetector = SilenceDetector(
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
    _rawAudioStream = null;
    _silenceDetector?.dispose();
    _silenceDetector = null;
    isRecording = false;
    return File(path);
  }
}
