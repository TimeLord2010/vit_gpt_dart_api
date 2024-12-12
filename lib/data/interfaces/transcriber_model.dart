import 'dart:io';

abstract class TranscribeModel {
  Stream<String> get transcribed;

  /// This method call should not add strings to the [transcribed] stream.
  Future<String> transcribeFromFile(File file);

  Future<void> startTranscribe();

  Future<void> endTranscription();

  void dispose();
}
