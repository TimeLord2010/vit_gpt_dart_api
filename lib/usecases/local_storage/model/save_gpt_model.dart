import '../../../data/dynamic_factories.dart';
import '../../../data/enums/gpt_model.dart';

Future<void> saveGptModel(GptModel model) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveChatModel(model);
}
