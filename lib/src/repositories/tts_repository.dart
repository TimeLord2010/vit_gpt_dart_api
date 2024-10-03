import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../data/enums/audio_format.dart';
import '../data/interfaces/tts_model.dart';
import '../factories/http_client.dart';

class TTSRepository extends TTSModel {
  @override
  Stream<Uint8List> getAudio({
    required String voice,
    required String input,
    bool highQuality = true,
    AudioFormat? format,
  }) async* {
    var path = 'https://api.openai.com/v1/audio/speech';
    var response = await httpClient.post(
      path,
      data: {
        'model': highQuality ? 'tts-1-hd' : 'tts-1',
        'input': input,
        'voice': voice,
        if (format != null) 'response_format': format.name,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );
    var data = response.data;
    Stream<Uint8List> stream = data.stream;
    yield* stream;
  }

  @override
  Future<List<String>> getVoices() async {
    return const ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
  }
}
