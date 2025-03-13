import 'dart:typed_data';

import 'package:vit_gpt_dart_api/repositories/openai/openai_realtime_repository.dart';
import 'package:vit_gpt_dart_api/usecases/local_storage/index.dart';

Future<void> main() async {
  var apiKey = 'YOUR API TOKEN';

  await updateApiToken(apiKey);

  var rep = OpenaiRealtimeRepository();

  rep.open();

  rep.onSpeech.listen((speech) {
    Uint8List bytes = speech.bytes;
    // Play your audio here
  });

  // Send the user audio here
  rep.sendUserAudio(Uint8List(0));

  await Future.delayed(Duration(seconds: 10), () {
    rep.close();
  });
}
