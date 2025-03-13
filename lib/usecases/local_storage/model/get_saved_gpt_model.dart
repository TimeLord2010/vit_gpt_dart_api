import '../../../data/dynamic_factories.dart';
import '../../../data/enums/gpt_model.dart';

Future<GptModel?> getSavedGptModel() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return GptModel.gpt4oMini;
  var rep = fac();

  var model = await rep.getChatModel();
  return model;
}
