import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<MicSendMode> getMicSendMode() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return MicSendMode.manual;
  var rep = fac();
  var mode = await rep.getMicSendMode();
  return mode ?? MicSendMode.manual;
}
