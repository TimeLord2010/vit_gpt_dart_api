import 'package:vit_gpt_dart_api/data/models/assistant.dart';

abstract class AssistantsModel {
  Future<List<Assistant>> findAssistants();
}
