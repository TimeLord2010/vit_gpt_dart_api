import 'dart:async';

import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_response.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_start.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_start.dart';

import '../data/models/message.dart';

abstract class BaseRealtimeRepository extends RealtimeModel {
  // MARK: Stream controllers
  final StreamController<TranscriptionStart> onTranscriptionStartController =
      StreamController<TranscriptionStart>.broadcast();
  final StreamController<TranscriptionEnd> onTranscriptionEndController =
      StreamController<TranscriptionEnd>.broadcast();
  final StreamController<TranscriptionItem> onTranscriptionItemController =
      StreamController<TranscriptionItem>.broadcast();

  final StreamController<SpeechStart> onSpeechStartController =
      StreamController<SpeechStart>.broadcast();
  final StreamController<SpeechEnd> onSpeechEndController =
      StreamController<SpeechEnd>.broadcast();
  final StreamController<SpeechItem> onSpeechController =
      StreamController<SpeechItem>.broadcast();

  final StreamController<Exception> onErrorController =
      StreamController<Exception>.broadcast();
  final StreamController<void> onConnectedController =
      StreamController<void>.broadcast();
  final StreamController<void> onDisconnectedController =
      StreamController<void>.broadcast();
  final StreamController<Duration> onRemaingTimeUpdatedController =
      StreamController<Duration>.broadcast();
  final StreamController<int> onRemainingRequestsUpdatedController =
      StreamController<int>.broadcast();
  final StreamController<int> onRemainingTokensUpdatedController =
      StreamController<int>.broadcast();
  final StreamController<RealtimeResponse> onResponseController =
      StreamController<RealtimeResponse>.broadcast();
  final StreamController<bool> onIsSendingInitialMessagesController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>>
      onConversationItemCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> onSocketDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<SpeechStart> get onSpeechStart => onSpeechStartController.stream;

  @override
  Stream<SpeechEnd> get onSpeechEnd => onSpeechEndController.stream;

  @override
  Stream<SpeechItem> get onSpeech => onSpeechController.stream;

  @override
  Stream<TranscriptionStart> get onTranscriptionStart {
    return onTranscriptionStartController.stream;
  }

  @override
  Stream<TranscriptionEnd> get onTranscriptionEnd =>
      onTranscriptionEndController.stream;

  @override
  Stream<TranscriptionItem> get onTranscriptionItem =>
      onTranscriptionItemController.stream;

  // MARK: System events

  @override
  Stream<Duration> get onRemaingTimeUpdated =>
      onRemaingTimeUpdatedController.stream;

  @override
  Stream<int> get onRemainingRequestsUpdated {
    return onRemainingRequestsUpdatedController.stream;
  }

  @override
  Stream<int> get onRemainingTokensUpdated =>
      onRemainingTokensUpdatedController.stream;

  @override
  Stream<RealtimeResponse> get onResponse => onResponseController.stream;

  @override
  Stream<void> get onConnectionClose => onDisconnectedController.stream;

  @override
  Stream<void> get onConnectionOpen => onConnectedController.stream;

  @override
  Stream<Exception> get onError => onErrorController.stream;

  @override
  Stream<bool> get onIsSendingInitialMessages =>
      onIsSendingInitialMessagesController.stream;

  @override
  Stream<Map<String, dynamic>> get onConversationItemCreated =>
      onConversationItemCreatedController.stream;

  @override
  Stream<Map<String, dynamic>> get onSocketData => onSocketDataController.stream;

  // MARK: State variables

  bool _isAiSpeaking = false;
  bool _isUserSpeaking = false;
  bool _isConnected = false;
  bool _isSendingInitialMessages = false;

  // MARK: Properties

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isAiSpeaking => _isAiSpeaking;

  set isAiSpeaking(bool value) {
    _isAiSpeaking = value;
  }

  @override
  bool get isUserSpeaking => _isUserSpeaking;

  set isUserSpeaking(bool value) {
    _isUserSpeaking = value;
  }

  @override
  bool get isSendingInitialMessages => _isSendingInitialMessages;

  /// Also adds the event to [onIsSendingInitialMessagesController], except
  /// if the current value in [isSendingInitialMessages] is the same as [value].
  void setIsSendingInitialMessages(bool value) {
    if (value == isSendingInitialMessages) {
      return;
    }
    _isSendingInitialMessages = value;
    onIsSendingInitialMessagesController.add(value);
  }

  set isConnected(bool value) => _isConnected = value;

  @override
  Uri? get uri => null;

  @override
  List<Message>? get initialMessages => null;

  // MARK: Methods

  @override
  void close() {
    onConnectedController.close();
    onDisconnectedController.close();
    onRemainingRequestsUpdatedController.close();
    onRemaingTimeUpdatedController.close();
    onRemainingTokensUpdatedController.close();
    onResponseController.close();
    onErrorController.close();
    onIsSendingInitialMessagesController.close();
    onConversationItemCreatedController.close();
    onSocketDataController.close();

    onSpeechStartController.close();
    onSpeechEndController.close();
    onSpeechController.close();

    onTranscriptionStartController.close();
    onTranscriptionEndController.close();
    onTranscriptionItemController.close();

    _isConnected = false;
    isAiSpeaking = false;
    _isUserSpeaking = false;
    _isSendingInitialMessages = false;
  }
}
