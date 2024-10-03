import '../../../data/dynamic_factories.dart';

Future<Duration> getSavedThreadsTtl() async {
  var rep = DynamicFactories.localStorage;
  var duration = await rep.getThreadsTtl();
  return duration ?? const Duration(days: 30);
}
