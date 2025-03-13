import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';

/// Returns true for high quality.
Future<bool> getTtsQuality() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return false;
  var rep = fac();
  var quality = await rep.getTtsQuality();
  return quality ?? false;
}
