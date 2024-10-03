import '../../data/models/conversation.dart';
import '../../factories/create_threads_repository.dart';

Future<Conversation?> loadThread(String id) async {
  var rep = createThreadsRepository();
  var thread = await rep.load(id);
  return thread;
}
