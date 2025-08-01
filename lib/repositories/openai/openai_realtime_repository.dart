import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/configuration.dart';
import 'package:vit_gpt_dart_api/data/enums/role.dart';
import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_response.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_start.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_start.dart';
import 'package:vit_gpt_dart_api/usecases/index.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class OpenaiRealtimeRepository extends RealtimeModel {
  // MARK: Stream controllers
  final _onTranscriptionStart =
      StreamController<TranscriptionStart>.broadcast();
  final _onTranscriptionEnd = StreamController<TranscriptionEnd>.broadcast();
  final _onTranscriptionItem = StreamController<TranscriptionItem>.broadcast();

  final _onSpeechStart = StreamController<SpeechStart>.broadcast();
  final _onSpeechEnd = StreamController<SpeechEnd>.broadcast();
  final _onSpeech = StreamController<SpeechItem>.broadcast();

  final _onError = StreamController<Exception>.broadcast();
  final _onConnected = StreamController<void>.broadcast();
  final _onDisconnected = StreamController<void>.broadcast();
  final _onRemaingTimeUpdated = StreamController<Duration>.broadcast();
  final _onRemainingRequestsUpdated = StreamController<int>.broadcast();
  final _onRemainingTokensUpdated = StreamController<int>.broadcast();
  final _onResponse = StreamController<RealtimeResponse>.broadcast();

  @override
  Stream<SpeechStart> get onSpeechStart => _onSpeechStart.stream;

  @override
  Stream<SpeechEnd> get onSpeechEnd => _onSpeechEnd.stream;

  @override
  Stream<SpeechItem> get onSpeech => _onSpeech.stream;

  @override
  Stream<TranscriptionStart> get onTranscriptionStart {
    return _onTranscriptionStart.stream;
  }

  @override
  Stream<TranscriptionEnd> get onTranscriptionEnd => _onTranscriptionEnd.stream;

  @override
  Stream<TranscriptionItem> get onTranscriptionItem =>
      _onTranscriptionItem.stream;

  // MARK: System events

  @override
  Stream<Duration> get onRemaingTimeUpdated => _onRemaingTimeUpdated.stream;

  @override
  Stream<int> get onRemainingRequestsUpdated {
    return _onRemainingRequestsUpdated.stream;
  }

  @override
  Stream<int> get onRemainingTokensUpdated => _onRemainingTokensUpdated.stream;

  @override
  Stream<RealtimeResponse> get onResponse => _onResponse.stream;

  @override
  Stream<void> get onConnectionClose => _onDisconnected.stream;

  @override
  Stream<void> get onConnectionOpen => _onConnected.stream;

  @override
  Stream<Exception> get onError => _onError.stream;

  // MARK: Variables

  WebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  bool _isAiSpeaking = false;
  bool _isUserSpeaking = false;

  bool _isConnected = false;

  String _aiTextResponseBuffer = '';

  final Logger _logger = VitGptDartConfiguration.createLogGroup([
    'OpenAiRealtimeRepository',
  ]);

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

  @override
  Uri? get uri => null;

  @override
  List<Message>? get initialMessages => null;

  // MARK: METHODS

  @override
  void stopAiSpeech() {
    var mapData = {"type": "response.cancel"};
    var strData = jsonEncode(mapData);
    socket?.sink.add(strData);
  }

  @override
  void commitUserAudio() {
    sendMessage({
      "type": "input_audio_buffer.commit",
    });
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    var mapData = {
      "type": "input_audio_buffer.append",
      "audio": base64Encode(audioData),
    };
    var strData = jsonEncode(mapData);
    socket?.sink.add(strData);
  }

  @override
  void close() {
    socket?.sink.close();
    socket = null;

    _onConnected.close();
    _onDisconnected.close();
    _onRemainingRequestsUpdated.close();
    _onRemaingTimeUpdated.close();
    _onRemainingTokensUpdated.close();
    _onResponse.close();
    _onError.close();

    _onSpeechStart.close();
    _onSpeechEnd.close();
    _onSpeech.close();

    _onTranscriptionStart.close();
    _onTranscriptionEnd.close();
    _onTranscriptionItem.close();

    _isConnected = false;
    isAiSpeaking = false;
    _isUserSpeaking = false;
  }

  @override
  Future<void> open() async {
    socket?.sink.close();

    String? token;
    token = await getSessionToken();
    token ??= await getApiToken();
    if (token == null) {
      _onError.add(Exception('No token found'));
      return;
    }

    var url = uri ??
        Uri(
          scheme: 'wss',
          host: 'api.openai.com',
          path: '/v1/realtime',
          queryParameters: {
            'model': 'gpt-4o-mini-realtime-preview',
          },
        );

    var s = socket = WebSocketChannel.connect(
      url,
      protocols: [
        "realtime",
        "openai-insecure-api-key.$token",
        "openai-beta.realtime-v1"
      ],
    );

    s.stream.listen(
      (event) async {
        String rawData = event;
        Map<String, dynamic> data = jsonDecode(rawData);
        String type = data['type'];
        await _processServerMessage(type, data);
      },
      onDone: () {
        _logger.i('Connection closed');
        _onDisconnected.add(null);
      },
      onError: (e) {
        _logger.e('Error: $e');
        _onError.add(e);
      },
    );
  }

  Future<void> _processServerMessage(
    String type,
    Map<String, dynamic> data,
  ) async {
    Future<void> Function()? handler;

    var map = <String, Future<void> Function()>{
      'error': () async {
        Map<String, dynamic> error = data['error'];
        String message = error['message'];
        _onError.add(Exception(message));
      },
      'session.created': () async {
        _logger.i('Session created');
        sessionConfig = data['session'];
        _isConnected = true;
        _onConnected.add(null);

        /// Sending initial messages
        var initialMsgs = initialMessages ?? [];
        var someHaveId = initialMsgs.any((x) => x.id != null);
        for (int i = 0; i < initialMsgs.length; i++) {
          Message? previousMsg = i > 0 ? initialMsgs[i - 1] : null;
          String? previousMsgId = previousMsg?.id;
          Message message = initialMsgs[i];
          var msg = <String, dynamic>{
            "type": "conversation.item.create",
            if (previousMsgId != null) 'previous_item_id': previousMsgId,
            'item': {
              if (message.id != null) 'id': message.id,
              'type': 'message',
              'role': message.role.name,
              'content': [
                {'type': 'input_text', 'text': message.text}
              ],
            },
          };
          sendMessage(msg);

          /// The operation will fail if we try to set "previous_item_id" to an
          /// id not found in the conversation object. To avoid that, lets
          /// wait for a set amount of time.
          if (someHaveId) await Future.delayed(Duration(milliseconds: 25));
        }
      },
      'session.updated': () async {
        _logger.i('Session updated');
        sessionConfig = data['session'];
      },
      'rate_limits.updated': () async {
        Map<String, dynamic> map = data;
        var rateLimits = List<Map<String, dynamic>>.from(map['rate_limits']);

        for (var limit in rateLimits) {
          if (limit['name'] == 'requests') {
            num amount = limit['remaining'];
            _onRemainingRequestsUpdated.add(amount.toInt());
          } else if (limit['name'] == 'tokens') {
            num amount = limit['remaining'];
            _onRemainingTokensUpdated.add(amount.toInt());
          }
        }
      },

      // User events
      'input_audio_buffer.speech_started': () async {
        _onSpeechStart.add(SpeechStart(
          id: data['item_id'],
          role: Role.user,
        ));
        _isUserSpeaking = true;
      },
      'input_audio_buffer.speech_stopped': () async {
        _onSpeechEnd.add(SpeechEnd(
          id: data['item_id'],
          role: Role.user,
        ));
        _isUserSpeaking = false;
      },
      'input_audio_buffer.committed': () async {
        _onSpeechEnd.add(SpeechEnd(
          id: data['item_id'],
          role: Role.user,
        ));
        _isUserSpeaking = false;
      },
      'conversation.item.input_audio_transcription.completed': () async {
        var id = data['item_id'];
        var transcript = data['transcript'];
        _onTranscriptionItem.add(TranscriptionItem(
          id: id,
          text: transcript,
          role: Role.user,
        ));
        _onTranscriptionEnd.add(TranscriptionEnd(
          id: id,
          content: transcript,
          role: Role.user,
        ));
      },

      // AI events
      'response.audio.delta': () async {
        // Updating ai speaking status
        if (!isAiSpeaking) {
          _onSpeechStart.add(SpeechStart(
            id: data['response_id'],
            role: Role.assistant,
          ));
        }
        isAiSpeaking = true;

        // Getting and sending audio data
        String base64Data = data['delta'];

        _onSpeech.add(SpeechItem<String>(
          id: data['response_id'],
          audioData: base64Data,
          role: Role.assistant,
        ));
      },
      'response.audio.done': () async {
        isAiSpeaking = false;
        _onSpeechEnd.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
        ));
      },
      'response.text.delta': () async {
        // This currently, is not called and it is unkown when it does receive
        // data.
        _logger.i('Text delta: $data');
        var delta = data['delta'];
        _aiTextResponseBuffer += delta;
        _onTranscriptionItem.add(TranscriptionItem(
          id: data['response_id'],
          text: delta,
          role: Role.assistant,
        ));
      },
      'response.text.done': () async {
        _onTranscriptionEnd.add(TranscriptionEnd(
          id: data['response_id'],
          role: Role.assistant,
          content: _aiTextResponseBuffer,
        ));
        _aiTextResponseBuffer = '';
      },
      'response.audio_transcript.delta': () async {
        String delta = data['delta'];
        _aiTextResponseBuffer += delta;
        _onTranscriptionItem.add(TranscriptionItem(
          id: data['response_id'],
          text: delta,
          role: Role.assistant,
        ));
      },
      'response.audio_transcript.done': () async {
        _onTranscriptionEnd.add(TranscriptionEnd(
          id: data['item_id'],
          role: Role.assistant,
          content: _aiTextResponseBuffer,
        ));
        _aiTextResponseBuffer = '';
      },
      'response.cancelled': () async {
        // Sent when [stopAiSpeech] is called.

        isAiSpeaking = false;
        _onSpeechEnd.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
        ));
      },
      'response.done': () async {
        var map = data['response'];
        var response = RealtimeResponse.fromMap(map);
        _onResponse.add(response);
      },
    };
    handler = map[type];

    if (handler == null) {
      _logger.w('No handler found for type: $type. Data: $data');
      return;
    }

    try {
      await handler();
    } on Exception catch (e) {
      _onError.add(e);
      _logger.e('Error while processing $type. Received data: $data', error: e);
    }
  }

  /// Can be overriden to implement server call to generate session token.
  Future<String?> getSessionToken() async => null;

  @override
  void sendMessage(Map<String, dynamic> map) {
    var strData = jsonEncode(map);
    socket?.sink.add(strData);
  }
}
