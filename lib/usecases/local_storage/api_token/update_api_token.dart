import 'package:vit_gpt_dart_api/data/interfaces/local_storage/local_storage_model.dart';

import '../../../data/dynamic_factories.dart';
import '../../../factories/http_client.dart';
import '../../../factories/logger.dart';

Future<void> updateApiToken(String token) async {
  logger.info('Setting api token: "$token"');

  var facFn = DynamicFactories.localStorageFactory;
  if (facFn != null) {
    LocalStorageModel rep = facFn();
    await rep.saveApiToken(token);
  }

  httpClient.options.headers['Authorization'] = 'Bearer $token';
}
