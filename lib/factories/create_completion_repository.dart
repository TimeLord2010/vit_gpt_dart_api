import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

CompletionModel createCompletionRepository() {
  var fac = DynamicFactories.completion;
  if (fac != null) return fac();
  throw CompletionRepository(
    dio: httpClient,
  );
}
