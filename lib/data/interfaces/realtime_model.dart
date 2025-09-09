import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_response.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_start.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_start.dart';

abstract class RealtimeModel {
  // MARK: user and AI events

  Stream<SpeechStart> get onSpeechStart;

  Stream<SpeechEnd> get onSpeechEnd;

  Stream<SpeechItem> get onSpeech;

  Stream<TranscriptionStart> get onTranscriptionStart;

  Stream<TranscriptionEnd> get onTranscriptionEnd;

  Stream<TranscriptionItem> get onTranscriptionItem;

  // MARK: System events

  Stream<void> get onConnectionOpen;

  Stream<void> get onConnectionClose;

  Stream<Duration> get onRemaingTimeUpdated;

  Stream<int> get onRemainingTokensUpdated;

  Stream<int> get onRemainingRequestsUpdated;

  Stream<Exception> get onError;

  Stream<RealtimeResponse> get onResponse;

  Stream<bool> get onIsSendingInitialMessages;

  Stream<Map<String, dynamic>> get onConversationItemCreated;

  // MARK: Properties

  bool get isConnected;

  bool get isAiSpeaking;

  bool get isUserSpeaking;

  bool get isSendingInitialMessages;

  List<Message>? get initialMessages;

  Iterable<Message> get sentInitialMessages;

  /// The URL of the server.
  Uri? get uri;

  // MARK: Methods

  /// Returns the headers to be sent with the socket connection.
  ///
  /// Unless you are dealing with a custom server, you should not
  /// override this method.
  Map<String, dynamic> getSocketHeaders(Map<String, dynamic> baseHeaders) {
    return baseHeaders;
  }

  void open();

  void close();

  /// Sends a audio chunk to the server.
  void sendUserAudio(Uint8List audioData);

  /// This is only required if the server does not support silence detection
  /// or it is not enabled.
  void commitUserAudio();

  void stopAiSpeech();

  void sendMessage(Map<String, dynamic> map);
}
