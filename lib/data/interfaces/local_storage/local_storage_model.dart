import 'package:vit_gpt_dart_api/data/interfaces/local_storage/thread_local_storage_model.dart';

import '../../enums/gpt_model.dart';
import 'audio_local_storage_model.dart';

abstract class LocalStorageModel
    with AudioLocalStorageModel, ThreadLocalStorageModel {
  // MARK: API Key

  Future<void> saveApiToken(String token);

  Future<String?> getApiToken();

  // MARK: Model

  Future<GptModel?> getChatModel();

  Future<void> saveChatModel(GptModel model);

  // MARK: Threads ttl

  Future<void> saveThreadsTtl(Duration duration);

  Future<Duration?> getThreadsTtl();
}
