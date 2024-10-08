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

  // MARK: TTS quality

  Future<bool?> getTtsQuality();

  Future<void> saveTtsQuality(bool highQuality);

  // MARK: Transcription language

  /// Input language in ISO-639-1 format.
  Future<String?> getTranscriptionLanguage();

  /// Input language in ISO-639-1 format.
  Future<void> saveTranscriptionLanguage(String lang);
}
