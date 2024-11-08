import '../../../../data/dynamic_factories.dart';

Future<String?> getThreadTitle(String id) async {
  var rep = DynamicFactories.localStorage;

  var title = await rep.getThreadTitle(id);
  return title;
}
