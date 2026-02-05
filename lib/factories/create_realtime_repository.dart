import 'package:vit_gpt_dart_api/data/dynamic_factories.dart';
import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/repositories/openai/openai_realtime_repository.dart';

RealtimeModel createRealtimeRepository({required String sonioxTemporaryKey}) {
  var fn = DynamicFactories.realtime;
  if (fn != null) {
    return fn();
  }
  return OpenaiRealtimeRepository(sonioxTemporaryKey: sonioxTemporaryKey);
}
