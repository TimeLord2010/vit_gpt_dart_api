import 'dart:io';

import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

class VoiceRecorderHandler {
  final recorder = DynamicFactories.recorder;

  bool isRecording = false;

  Future<double> get amplitude async => recorder.amplitude;

  Future<void> dispose() async {
    isRecording = false;
    await recorder.dispose();
  }

  @Deprecated('Use [recorder.onAmplitude] instead.')
  Stream<double> getAmplitudes() {
    var stream = recorder.onAmplitude();
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
    isRecording = false;
    return File(path);
  }
}
