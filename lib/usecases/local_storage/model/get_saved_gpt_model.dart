import '../../../data/dynamic_factories.dart';
import '../../../data/enums/gpt_model.dart';

Future<GptModel?> getSavedGptModel() async {
  var rep = DynamicFactories.localStorage;
  var model = await rep.getChatModel();
  return model;
}
