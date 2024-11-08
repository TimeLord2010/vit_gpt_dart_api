import '../../../../data/dynamic_factories.dart';

Future<void> saveThreadTitle(String id, String title) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveThreadTitle(id, title);
}
