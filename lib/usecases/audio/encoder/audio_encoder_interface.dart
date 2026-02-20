import 'dart:typed_data';

/// Interface for encoding PCM audio to compressed formats
abstract class AudioEncoderInterface {
  /// Converts PCM16 audio data to MP3 format
  ///
  /// Parameters:
  /// - [pcmData]: Raw PCM16 audio data (signed 16-bit little-endian)
  /// - [sampleRate]: Sample rate in Hz (e.g., 24000)
  /// - [numChannels]: Number of audio channels (1 for mono, 2 for stereo)
  ///
  /// Returns: Uint8List containing the MP3 encoded audio data
  Future<Uint8List> encodePcmToMp3({
    required Uint8List pcmData,
    required int sampleRate,
    required int numChannels,
  });
}
