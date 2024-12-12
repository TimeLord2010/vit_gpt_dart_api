import 'dart:io';

abstract class TranscribeModel {
  Stream<String> get transcribed;

  Stream<double> get onMicVolumeChange;

  Stream<bool> get onSilenceChange;

  /// This method should not add strings to the [transcribed] stream.
  Future<String> transcribeFromFile(File file);

  Future<void> startTranscribe();

  Future<void> endTranscription();

  void dispose();
}
