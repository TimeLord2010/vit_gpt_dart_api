import 'package:vit_gpt_dart_api/factories/http_client.dart';

import '../data/dynamic_factories.dart';
import '../data/interfaces/threads_model.dart';
import '../repositories/threads_repository.dart';

ThreadsModel createThreadsRepository() {
  var fac = DynamicFactories.threads;
  if (fac != null) return fac();
  return ThreadsRepository(httpClient);
}
