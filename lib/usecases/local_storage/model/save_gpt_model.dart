import '../../../data/dynamic_factories.dart';

Future<void> saveGptModel(String model) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();

  await rep.saveChatModel(model);
}
