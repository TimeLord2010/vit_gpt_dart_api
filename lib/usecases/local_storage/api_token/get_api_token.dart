import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<String?> getApiToken() async {
  var rep = DynamicFactories.localStorage;
  var token = await rep.getApiToken();
  return token;
}
