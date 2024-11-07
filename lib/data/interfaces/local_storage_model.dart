import 'package:vit_gpt_dart_api/data/enums/mic_send_mode.dart';

import '../enums/gpt_model.dart';

abstract class LocalStorageModel extends AudioLocalStorage {
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

abstract class AudioLocalStorage {
  // MARK: TTS quality

  Future<bool?> getTtsQuality();

  Future<void> saveTtsQuality(bool highQuality);

  // MARK: Transcription language

  /// Input language in ISO-639-1 format.
  Future<String?> getTranscriptionLanguage();

  /// Input language in ISO-639-1 format.
  Future<void> saveTranscriptionLanguage(String lang);

  // MARK: Speaker voice

  Future<String?> getSpeakerVoice();

  Future<void> saveSpeakerVoice(String? voice);

  // MARK: Mic send mode

  Future<MicSendMode?> getMicSendMode();

  Future<void> saveMicSendMode(MicSendMode value);
}
