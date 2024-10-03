import '../../factories/create_threads_repository.dart';
import '../local_storage/threads/delete_saved_thread.dart';

Future<void> deleteThread(String id) async {
  var rep = createThreadsRepository();
  await rep.delete(id);
  await deleteSavedThread(id);
}
