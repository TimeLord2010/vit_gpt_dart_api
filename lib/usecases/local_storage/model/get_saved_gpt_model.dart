import '../../../data/dynamic_factories.dart';

Future<String?> getSavedGptModel() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return 'gpt-4.1-mini';
  var rep = fac();

  var model = await rep.getChatModel();
  return model;
}
