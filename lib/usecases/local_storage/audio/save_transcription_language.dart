import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<void> saveTranscriptionLanguage(String lang) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveTranscriptionLanguage(lang);
}
