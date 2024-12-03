import '../data/dynamic_factories.dart';
import '../data/interfaces/threads_model.dart';
import '../repositories/threads_repository.dart';

ThreadsModel createThreadsRepository() {
  var fac = DynamicFactories.threads;
  if (fac != null) fac();
  return ThreadsRepository();
}
