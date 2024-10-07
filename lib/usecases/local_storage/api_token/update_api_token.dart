import '../../../data/dynamic_factories.dart';
import '../../../factories/http_client.dart';
import '../../../factories/logger.dart';

Future<void> updateApiToken(String token) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveApiToken(token);
  logger.info('Setting api token: "$token"');
  httpClient.options.headers['Authorization'] = 'Bearer $token';
}
