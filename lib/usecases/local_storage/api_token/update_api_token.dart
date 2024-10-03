import '../../../data/dynamic_factories.dart';
import '../../../factories/http_client.dart';

Future<void> updateApiToken(String token) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveApiToken(token);
  httpClient.options.headers['Authorization'] = 'Bearer $token';
}
