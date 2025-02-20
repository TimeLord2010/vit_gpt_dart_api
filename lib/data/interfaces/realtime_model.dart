import 'dart:typed_data';

abstract class RealtimeModel {
  Stream<void> get onConnectionOpen;

  Stream<void> get onConnectionClose;

  /// Stream of AI text. This should not output any object that is encoded
  /// as a json or other format.
  Stream<String> get onAiText;

  /// Stream of user text. This should not output any object that is encoded
  /// as a json or other format.
  Stream<String> get onUserText;

  Stream<Uint8List> get onAiAudio;

  Stream<Exception> get onError;

  Stream<void> get onUserAudioCommited;

  Stream<void> get onUserSpeechBegin;

  Stream<void> get onUserSpeechEnd;

  Stream<void> get onAiSpeechBegin;

  Stream<void> get onAiSpeechEnd;

  Stream<Duration> get onRemaingTimeUpdated;

  Stream<int> get onRemainingRequestsUpdated;

  void open();

  void close();

  void sendUserAudio(Uint8List audioData);

  /// This is only required if the server does not support silence detection
  /// or it is not enabled.
  void commitUserAudio();
}
