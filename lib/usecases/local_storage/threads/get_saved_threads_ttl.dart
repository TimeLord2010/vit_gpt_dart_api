import '../../../data/dynamic_factories.dart';

Future<Duration> getSavedThreadsTtl() async {
  var fac = DynamicFactories.localStorage;
  if (fac == null) return Duration(days: 30);
  var rep = fac();

  var duration = await rep.getThreadsTtl();
  return duration ?? const Duration(days: 30);
}
