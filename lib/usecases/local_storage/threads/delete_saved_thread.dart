import '../../../data/dynamic_factories.dart';

Future<void> deleteSavedThread(String id) async {
  var rep = DynamicFactories.localStorage;
  await rep.deleteThread(id);
}
