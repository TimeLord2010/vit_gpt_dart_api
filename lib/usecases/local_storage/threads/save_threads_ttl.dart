import '../../../data/dynamic_factories.dart';

Future<void> saveThreadsTtl(Duration duration) async {
  var rep = DynamicFactories.localStorage;
  await rep.saveThreadsTtl(duration);
}
