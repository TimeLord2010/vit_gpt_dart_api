import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

TTSModel createTtsRepository() {
  var fac = DynamicFactories.tts;
  if (fac != null) {
    return fac();
  }
  return TTSRepository();
}
