import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<MicSendMode> getMicSendMode() async {
  var rep = DynamicFactories.localStorage;
  var mode = await rep.getMicSendMode();
  return mode ?? MicSendMode.manual;
}
