import 'package:vit_gpt_dart_api/data/enums/audio_model.dart';

import '../data/configuration.dart';
import '../data/dynamic_factories.dart';
import '../data/interfaces/transcriber_model.dart';
import '../repositories/transcriber_repository.dart';
import 'http_client.dart';

TranscribeModel createTranscriberRepository() {
  var fac = DynamicFactories.speeachToText;
  if (fac != null) fac();
  return TranscriberRepository(
    dio: httpClient,
    model: AudioModel.whisper1,
    language: VitGptConfiguration.transcriptionLanguage,
  );
}
