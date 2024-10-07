import 'package:vit_gpt_dart_api/data/models/assistant.dart';
import 'package:vit_gpt_dart_api/repositories/assistants_repository.dart';

Future<List<Assistant>> listAssistants() async {
  var rep = AssistantsRepository();
  var list = await rep.findAssistants();
  return list;
}
