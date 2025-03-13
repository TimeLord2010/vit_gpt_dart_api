import '../../../data/dynamic_factories.dart';

Future<List<String>> getSavedThreadIds() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return [];
  var rep = fac();
  var ids = await rep.getThreads();
  return ids;
}
