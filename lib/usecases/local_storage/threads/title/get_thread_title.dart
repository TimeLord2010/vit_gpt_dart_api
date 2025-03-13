import '../../../../data/dynamic_factories.dart';

Future<String?> getThreadTitle(String id) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return null;
  var rep = fac();

  var title = await rep.getThreadTitle(id);
  return title;
}
