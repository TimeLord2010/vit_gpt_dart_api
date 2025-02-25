import 'package:vit_gpt_dart_api/repositories/openai/openai_realtime_repository.dart';
import 'package:vit_gpt_dart_api/usecases/local_storage/index.dart';

Future<void> main() async {
  var apiKey = 'YOUR API TOKEN';

  await updateApiToken(apiKey);

  var rep = OpenaiRealtimeRepository();

  rep.open();

  await Future.delayed(Duration(seconds: 10), () {
    rep.close();
  });
}
