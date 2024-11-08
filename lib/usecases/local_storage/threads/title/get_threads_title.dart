import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<Map<String, String>> getThreadsTitle(Iterable<String> ids) async {
  var rep = DynamicFactories.localStorage;
  var result = await rep.getThreadsTitle(ids);
  return result;
}
