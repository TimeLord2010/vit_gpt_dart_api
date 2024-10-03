abstract class AudioRecorderModel {
  Future<bool> requestPermission();

  Future<void> start();

  Future<String?> stop();

  Future<void> dispose();

  Future<double> get amplitude;

  Stream<double> onAmplitude([Duration? duration]);
}
