import 'package:vit_gpt_dart_api/data/configuration.dart';
import 'package:vit_gpt_dart_api/data/interfaces/local_storage/local_storage_model.dart';

import '../../../data/dynamic_factories.dart';
import '../../../factories/http_client.dart';

Future<void> updateApiToken(String token) async {
  var logger = VitGptConfiguration.logger;
  logger.i('Setting api token: "$token"');

  var facFn = DynamicFactories.localStorageFactory;
  if (facFn != null) {
    LocalStorageModel rep = facFn();
    await rep.saveApiToken(token);
  }

  httpClient.options.headers['Authorization'] = 'Bearer $token';
}
