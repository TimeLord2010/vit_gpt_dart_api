import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<Map<String, String>> getThreadsTitle(Iterable<String> ids) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return {};
  var rep = fac();
  var result = await rep.getThreadsTitle(ids);
  return result;
}
