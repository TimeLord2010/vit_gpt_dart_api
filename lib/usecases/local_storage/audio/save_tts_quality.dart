import 'package:vit_gpt_dart_api/data/configuration.dart';
import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

Future<void> saveTtsQuality(bool highQuality) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();

  await rep.saveTtsQuality(highQuality);
  VitGptDartConfiguration.useHighQualityTts = highQuality;
}
