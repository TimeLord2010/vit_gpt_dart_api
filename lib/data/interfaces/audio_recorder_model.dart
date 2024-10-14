/// Models the interface of a audio recorder.
abstract class AudioRecorderModel {
  /// Requests permission on the microphone.
  Future<bool> requestPermission();

  /// Starts to record using the microphone.
  Future<void> start();

  /// Stop the recording on the micriphone.
  Future<String?> stop();

  /// Disposes any used resources.
  Future<void> dispose();

  /// Returns the current amplitude of the microphone in a 0 to 1 range.
  Future<double> get amplitude;

  /// Returns the amplitude changes on the microphone in a 0 to 1 range.
  Stream<double> onAmplitude([Duration? duration]);

  /// Returns the amplitude changes on the microphone in decibels.
  Stream<double> onRawAmplitude([Duration? duration]);
}
