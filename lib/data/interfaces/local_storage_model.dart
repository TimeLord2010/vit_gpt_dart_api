import '../enums/gpt_model.dart';

abstract class LocalStorageModel {
  // MARK: API Key

  Future<void> saveApiToken(String token);

  Future<String?> getApiToken();

  // MARK: Thread ids

  Future<List<String>> getThreads();

  Future<void> deleteThread(String id);

  Future<void> saveThread(String id);

  // MARK: Model

  Future<GptModel?> getChatModel();

  Future<void> saveChatModel(GptModel model);

  // MARK: Threads ttl

  Future<void> saveThreadsTtl(Duration duration);

  Future<Duration?> getThreadsTtl();
}
