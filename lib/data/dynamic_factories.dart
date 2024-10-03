import 'package:vit_gpt_dart_api/data/interfaces/audio_recorder_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/local_storage_model.dart';

class DynamicFactories {
  static AudioRecorderModel Function()? recorderFactory;
  static AudioRecorderModel get recorder {
    return _create(recorderFactory, 'Audio recorder');
  }

  static LocalStorageModel Function()? localStorageFactory;
  static LocalStorageModel get localStorage {
    return _create(localStorageFactory, 'Local Storage');
  }
}

T _create<T>(T Function()? fac, String name) {
  if (fac == null) {
    throw Exception('$name factory not registered');
  }
  return fac();
}
