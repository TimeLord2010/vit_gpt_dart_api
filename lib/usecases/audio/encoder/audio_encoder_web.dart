import 'dart:js_interop';
import 'dart:typed_data';

import 'audio_encoder_interface.dart';

/// Audio encoder implementation for Web platform using lamejs
class AudioEncoder implements AudioEncoderInterface {
  @override
  Future<Uint8List> encodePcmToMp3({
    required Uint8List pcmData,
    required int sampleRate,
    required int numChannels,
  }) async {
    // Call JavaScript function to encode PCM to MP3 using lamejs
    try {
      final result = await _encodePcmToMp3JS(
        pcmData.toJS,
        sampleRate,
        numChannels,
      ).toDart;

      // Convert JS Uint8Array to Dart Uint8List
      return result.toDart;
    } catch (e) {
      throw Exception(
        'Failed to encode PCM to MP3 on web platform: $e\n'
        'Make sure lamejs is included in your web/index.html',
      );
    }
  }
}

/// JavaScript interop function to encode PCM to MP3
@JS('encodePcmToMp3')
external JSPromise<JSUint8Array> _encodePcmToMp3JS(
  JSUint8Array pcmData,
  int sampleRate,
  int numChannels,
);
