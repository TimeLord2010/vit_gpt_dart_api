import 'package:dio/dio.dart';

var httpClient = Dio(BaseOptions(
  baseUrl: 'https://api.openai.com/v1',
  headers: {
    'OpenAI-Beta': 'assistants=v2',
  },
));
