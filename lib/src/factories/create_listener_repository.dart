import '../data/interfaces/listener_model.dart';
import '../repositories/listener_repository.dart';
import 'http_client.dart';

ListenerModel createListenerRepository() {
  return ListenerRepository(dio: httpClient);
}
