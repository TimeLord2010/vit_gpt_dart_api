import 'dart:typed_data';

abstract class RealtimeModel {
  // MARK: User events

  /// Stream of user text. This should not output any object that is encoded
  /// as a json or other format.
  Stream<String> get onUserText;

  Stream<void> get onUserSpeechBegin;

  Stream<void> get onUserSpeechEnd;

  // MARK: AI events

  /// Stream of AI text. This should not output any object that is encoded
  /// as a json or other format.
  Stream<String> get onAiText;

  Stream<void> get onAiTextEnd;

  Stream<Uint8List> get onAiAudio;

  Stream<void> get onAiSpeechBegin;

  Stream<void> get onAiSpeechEnd;

  // MARK: System events

  Stream<void> get onConnectionOpen;

  Stream<void> get onConnectionClose;

  Stream<Duration> get onRemaingTimeUpdated;

  Stream<int> get onRemainingRequestsUpdated;

  Stream<Exception> get onError;

  // MARK: Properties

  bool get isConnected;

  bool get isAiSpeaking;

  bool get isUserSpeaking;

  Uri? get uri;

  // MARK: Methods

  Future<String?> getSessionToken();

  Map<String, dynamic> getSocketHeaders(Map<String, dynamic> baseHeaders);

  void open();

  void close();

  /// Sends a audio chunk to the server.
  void sendUserAudio(Uint8List audioData);

  /// This is only required if the server does not support silence detection
  /// or it is not enabled.
  void commitUserAudio();

  void stopAiSpeech();
}
