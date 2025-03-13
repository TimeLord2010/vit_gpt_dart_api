import '../../../data/dynamic_factories.dart';

Future<void> deleteSavedThread(String id) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();

  await rep.deleteThread(id);
}
