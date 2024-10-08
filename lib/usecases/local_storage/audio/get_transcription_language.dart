import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<String?> getTranscriptionLanguage() async {
  var rep = DynamicFactories.localStorage;
  var lang = await rep.getTranscriptionLanguage();
  return lang ?? 'pt';
}
