import '../../../data/dynamic_factories.dart';

Future<void> saveThreadsTtl(Duration duration) async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return;
  var rep = fac();
  await rep.saveThreadsTtl(duration);
}
