import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<String?> getTranscriptionLanguage() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return null;
  var rep = fac();
  var lang = await rep.getTranscriptionLanguage();
  return lang ?? 'pt';
}
