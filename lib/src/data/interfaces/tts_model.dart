import 'dart:typed_data';

import '../enums/audio_format.dart';

// Text to speech.
abstract class TTSModel {
  Future<List<String>> getVoices();

  Stream<Uint8List> getAudio({
    required String voice,
    required String input,
    bool highQuality,
    AudioFormat? format,
  });
}
