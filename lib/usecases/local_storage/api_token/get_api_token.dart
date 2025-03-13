import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';
import 'package:vit_gpt_dart_api/data/interfaces/local_storage/local_storage_model.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';

Future<String?> getApiToken() async {
  var fac = DynamicFactories.localStorage;

  if (fac != null) {
    LocalStorageModel rep = fac();
    var token = await rep.getApiToken();
    return token;
  }

  // Falling back to attempt to get token from http client
  var headers = httpClient.options.headers;
  if (headers.containsKey('Authorization')) {
    String? token = headers['Authorization'];

    // Removing 'Bearer ' prefix
    if (token != null && token.startsWith('Bearer ')) {
      token = token.substring(7);
      return token;
    }
  }

  return null;
}
