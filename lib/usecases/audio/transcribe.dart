import 'dart:io';

import '../../data/configuration.dart';
import '../../data/enums/audio_model.dart';
import '../../factories/create_listener_repository.dart';

Future<String> transcribe(File file) async {
  var rep = createListenerRepository();
  var text = await rep.listen(
    audio: file,
    model: AudioModel.whisper1,
    language: VitGptConfiguration.transcriptionLanguage,
  );
  return text;
}
