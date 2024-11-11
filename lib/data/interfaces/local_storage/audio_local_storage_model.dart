import '../../enums/mic_send_mode.dart';

mixin AudioLocalStorageModel {
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
