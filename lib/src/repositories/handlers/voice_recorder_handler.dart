import 'dart:io';

import 'package:chatgpt_chat/factories/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderHandler {
  final _recorder = AudioRecorder();

  bool isRecording = false;

  Future<double> get amplitude async {
    var value = await _recorder.getAmplitude();
    return value.current / value.max;
  }

  Future<void> dispose() async {
    isRecording = false;
    await _recorder.dispose();
  }

  Stream<double> getAmplitudes() {
    const interval = Duration(milliseconds: 100);
    var stream = _recorder.onAmplitudeChanged(interval);
    return stream.map((event) {
      var calculated = event.current / event.max;
      if (calculated > 1) {
        logger.warn('Invalid amplitude: ${event.current} / ${event.max}');
        return 1;
      }
      return calculated;
    });
  }

  /// Starts the audio recording.
  ///
  /// This method will return false if the platform does not have the required
  /// permission.
  Future<bool> start() async {
    // Check and request permission if needed
    var hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return false;
    }
    var dir = await getApplicationDocumentsDirectory();
    // Start recording to file

    await _recorder.start(
      const RecordConfig(
        // We choose this uncompressed format so when dont require decoding
        // later.
        encoder: AudioEncoder.wav,
      ),
      path: '${dir.path}/myInput.wav',
    );

    isRecording = true;
    return true;
  }

  /// Stops the audio recorder.
  ///
  /// Throws a [StateError] if the recorder is not active.
  Future<File> stop() async {
    String? path = await _recorder.stop();
    if (path == null) {
      throw StateError('Was not recording to stop');
    }
    isRecording = false;
    return File(path);
  }
}
