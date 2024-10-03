import 'package:dio/dio.dart';

var httpClient = Dio(BaseOptions(
  headers: {
    'OpenAI-Beta': 'assistants=v2',
  },
));
