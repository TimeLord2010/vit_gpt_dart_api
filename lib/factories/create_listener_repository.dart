import '../data/dynamic_factories.dart';
import '../data/interfaces/listener_model.dart';
import '../repositories/listener_repository.dart';
import 'http_client.dart';

ListenerModel createListenerRepository() {
  var fac = DynamicFactories.speeachToText;
  if (fac != null) fac();
  return ListenerRepository(dio: httpClient);
}
