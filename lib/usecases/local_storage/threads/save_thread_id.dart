import '../../../data/dynamic_factories.dart';

Future<void> saveThreadId(String id) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();

  await rep.saveThread(id);
}
