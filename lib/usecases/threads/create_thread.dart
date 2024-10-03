import '../../data/models/conversation.dart';
import '../../factories/create_threads_repository.dart';
import '../../factories/logger.dart';
import '../local_storage/threads/save_thread_id.dart';

Future<Conversation> createThread() async {
  var rep = createThreadsRepository();
  var conversation = await rep.create();
  var id = conversation.id;
  if (id != null) {
    await saveThreadId(id);
  } else {
    logger.warn('Unable to save thread: No id.');
  }
  return conversation;
}
