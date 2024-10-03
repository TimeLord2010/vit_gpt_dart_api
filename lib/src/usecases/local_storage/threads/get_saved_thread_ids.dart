import '../../../data/dynamic_factories.dart';

Future<List<String>> getSavedThreadIds() async {
  var rep = DynamicFactories.localStorage;
  var ids = await rep.getThreads();
  return ids;
}
