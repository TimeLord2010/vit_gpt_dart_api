import 'dart:typed_data';

import 'audio_encoder_interface.dart';

/// Stub implementation for unsupported platforms
class AudioEncoder implements AudioEncoderInterface {
  @override
  Future<Uint8List> encodePcmToMp3({
    required Uint8List pcmData,
    required int sampleRate,
    required int numChannels,
  }) async {
    throw UnsupportedError(
      'Audio encoding is not supported on this platform. '
      'Please use Android, iOS, or Web platforms.',
    );
  }
}
