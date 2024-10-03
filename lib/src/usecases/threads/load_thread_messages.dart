import '../../data/models/message.dart';
import '../../factories/create_threads_repository.dart';

Future<List<Message>> loadThreadMessages(String threadId) async {
  var rep = createThreadsRepository();
  var messages = await rep.listMessages(threadId: threadId);
  return messages;
}
