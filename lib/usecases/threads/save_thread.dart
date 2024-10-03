import '../../factories/create_threads_repository.dart';

Future<void> saveThread(String threadId, Map<String, String> metadata) async {
  var rep = createThreadsRepository();
  await rep.saveMetadata(threadId, metadata);
}
