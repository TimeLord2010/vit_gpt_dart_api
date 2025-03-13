import 'package:vit_gpt_dart_api/data/configuration.dart';
import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<void> saveTranscriptionLanguage(String lang) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();
  await rep.saveTranscriptionLanguage(lang);
  VitGptDartConfiguration.transcriptionLanguage = lang;
}
