import 'package:dio/dio.dart';

import '../../data/models/conversation.dart';
import '../../factories/create_threads_repository.dart';

Future<Conversation?> loadThread(String id) async {
  try {
    var rep = createThreadsRepository();
    var thread = await rep.load(id);
    return thread;
  } on DioException catch (e) {
    var code = e.response?.statusCode;
    if (code == 404) return null;
    rethrow;
  }
}
