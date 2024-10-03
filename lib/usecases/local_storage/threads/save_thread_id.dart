import '../../../data/dynamic_factories.dart';

Future<void> saveThreadId(String id) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveThread(id);
}
