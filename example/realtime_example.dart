import 'dart:typed_data';

import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<void> main() async {
  var apiKey = 'YOUR API TOKEN';

  await updateApiToken(apiKey);

  RealtimeModel rep = createRealtimeRepository();

  rep.open();

  rep.onSpeech.listen((speech) {
    // Play your audio here
  });

  // Send the user audio here
  rep.sendUserAudio(Uint8List(0));

  await Future.delayed(Duration(seconds: 10), () {
    rep.close();
  });
}
