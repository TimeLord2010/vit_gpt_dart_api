import '../../../data/dynamic_factories.dart';
import '../../../data/enums/gpt_model.dart';

Future<void> saveGptModel(GptModel model) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();

  await rep.saveChatModel(model);
}
