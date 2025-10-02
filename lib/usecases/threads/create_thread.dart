import 'package:vit_gpt_dart_api/factories/create_log_group.dart';

import '../../data/models/conversation.dart';
import '../../factories/create_threads_repository.dart';
import '../local_storage/threads/save_thread_id.dart';

var _logger = createGptDartLogger('createThread');

Future<Conversation> createThread() async {
  var rep = createThreadsRepository();
  var conversation = await rep.create();
  var id = conversation.id;
  if (id != null) {
    await saveThreadId(id);
  } else {
    _logger.w('Unable to save thread: No id.');
  }
  return conversation;
}
