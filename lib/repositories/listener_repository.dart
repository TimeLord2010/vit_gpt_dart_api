import 'dart:io';

import 'package:dio/dio.dart';

import '../data/enums/audio_model.dart';
import '../data/interfaces/listener_model.dart';

class ListenerRepository extends ListenerModel {
  final Dio dio;

  ListenerRepository({
    required this.dio,
  });

  @override
  Future<String> listen({
    required File audio,
    required AudioModel model,
    String? language,
    String? prompt,
    double? temperature,
  }) async {
    var url = 'https://api.openai.com/v1/audio/transcriptions';
    var form = FormData.fromMap({
      'file': await MultipartFile.fromFile(audio.path),
      'model': model.toString(),
      if (language != null) 'language': language,
      if (prompt != null) 'prompt': prompt,
      if (temperature != null) 'temperature': temperature,
    });
    var response = await dio.post(
      url,
      data: form,
    );
    Map<String, dynamic> map = response.data;
    String text = map['text'];
    return text;
  }
}
