import '../../../../data/dynamic_factories.dart';

Future<void> saveThreadTitle(String id, String title) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();
  await rep.saveThreadTitle(id, title);
}
