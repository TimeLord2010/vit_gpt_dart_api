import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/usecases/index.dart';
import 'package:vit_logger/vit_logger.dart';
import 'package:web_socket_channel/io.dart';

final _logger = TerminalLogger(
  event: 'OpenaiRealtimeRepository',
);

class OpenaiRealtimeRepository extends RealtimeModel {
  // MARK: Stream controllers
  final _onUserText = StreamController<String>.broadcast();
  final _onUserSpeechBegin = StreamController<void>.broadcast();
  final _onUserSpeechEnd = StreamController<void>.broadcast();

  final _onAiText = StreamController<String>.broadcast();
  final _onAiAudio = StreamController<Uint8List>.broadcast();
  final _onAiTextEnd = StreamController<void>.broadcast();
  final _onAiSpeechBegin = StreamController<void>.broadcast();
  final _onAiSpeechEnd = StreamController<void>.broadcast();

  final _onError = StreamController<Exception>.broadcast();
  final _onConnected = StreamController<void>.broadcast();
  final _onDisconnected = StreamController<void>.broadcast();
  final _onRemaingTimeUpdated = StreamController<Duration>.broadcast();
  final _onRemainingRequestsUpdated = StreamController<int>.broadcast();

  // MARK: User events

  @override
  Stream<String> get onUserText => _onUserText.stream;

  @override
  Stream<void> get onUserSpeechBegin => _onUserSpeechBegin.stream;

  @override
  Stream<void> get onUserSpeechEnd => _onUserSpeechEnd.stream;

  // MARK: AI events

  @override
  Stream<Uint8List> get onAiAudio => _onAiAudio.stream;

  @override
  Stream<void> get onAiTextEnd => _onAiTextEnd.stream;

  @override
  Stream<String> get onAiText => _onAiText.stream;

  @override
  Stream<void> get onAiSpeechBegin => _onAiSpeechBegin.stream;

  @override
  Stream<void> get onAiSpeechEnd => _onAiSpeechEnd.stream;

  // MARK: System events

  @override
  Stream<Duration> get onRemaingTimeUpdated => _onRemaingTimeUpdated.stream;

  @override
  Stream<int> get onRemainingRequestsUpdated {
    return _onRemainingRequestsUpdated.stream;
  }

  @override
  Stream<void> get onConnectionClose => _onDisconnected.stream;

  @override
  Stream<void> get onConnectionOpen => _onConnected.stream;

  @override
  Stream<Exception> get onError => _onError.stream;

  // MARK: Variables

  IOWebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  bool _isAiSpeaking = false;
  final bool _isUserSpeaking = false;

  // MARK: Properties

  @override
  bool get isAiSpeaking => _isAiSpeaking;

  @override
  bool get isUserSpeaking => _isUserSpeaking;

  @override
  Uri? get uri => null;

  // MARK: METHODS

  @override
  void commitUserAudio() {
    _logger.debug('Committing user audio');
    socket?.sink.add({
      "type": "input_audio_buffer.commit",
    });
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    _logger.debug('Sending user audio');
    socket?.sink.add({
      "type": "input_audio_buffer.append",
      "audio": String.fromCharCodes(audioData),
    });
  }

  @override
  void close() {
    socket?.sink.close();
    socket = null;

    _onConnected.close();
    _onDisconnected.close();
    _onRemainingRequestsUpdated.close();
    _onRemaingTimeUpdated.close();
    _onError.close();

    _onUserText.close();
    _onUserSpeechBegin.close();
    _onUserSpeechEnd.close();

    _onAiText.close();
    _onAiAudio.close();
    _onAiTextEnd.close();
    _onAiSpeechBegin.close();
    _onAiSpeechEnd.close();
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

    var opts = getSocketHeaders({
      'Authorization': 'Bearer $token',
      'OpenAI-Beta': 'realtime=v1',
    });

    var s = socket = IOWebSocketChannel.connect(
      url,
      headers: opts,
    );

    _onConnected.add(null);

    s.stream.listen(
      (event) async {
        String rawData = event;
        _logger.info('Received event: $rawData');
        Map<String, dynamic> data = jsonDecode(rawData);
        String type = data['type'];
        await _processServerMessage(type, data);
      },
      onDone: () {
        _logger.info('Connection closed');
        _onDisconnected.add(null);
      },
      onError: (e) {
        _logger.error('Error: $e');
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
        sessionConfig = data['session'];
        _onConnected.add(null);
      },
      'session.updated': () async {
        sessionConfig = data['session'];
      },
      'rate_limits.updated': () async {
        Map<String, dynamic> map = data;
        var rateLimits = List<Map<String, dynamic>>.from(map['rate_limits']);

        for (var limit in rateLimits) {
          if (limit['name'] == 'requests') {
            _onRemainingRequestsUpdated.add(limit['remaining']);
          } else if (limit['name'] == 'tokens') {
            _onRemaingTimeUpdated
                .add(Duration(seconds: limit['reset_seconds']));
          }
        }
      },

      // User events
      'input_audio_buffer.speech_started': () async {
        _onUserSpeechBegin.add(null);
      },
      'input_audio_buffer.speech_stopped': () async {
        _onUserSpeechEnd.add(null);
      },
      'conversation.item.create': () async {
        Map<String, dynamic> map = data;
        List<Map<String, dynamic>> items = map['items'];

        for (var item in items) {
          String type = item['type'];
          String role = item['role'];
          if (type == 'text') {
            if (role == 'user') {
              List<Map<String, dynamic>> content = item['content'];
              for (var c in content) {
                if (c['type'] == 'input_text') {
                  String text = c['text'];
                  _onUserText.add(text);
                }
              }
            }
          }
        }
      },

      // AI events
      'response.audio.delta': () async {
        // Updating ai speaking status
        if (!_isAiSpeaking) {
          _onAiSpeechBegin.add(null);
        }
        _isAiSpeaking = true;

        // Getting and sending audio data
        String base64Data = data['delta'];
        var bytes = Uint8List.fromList(base64Data.codeUnits);
        _onAiAudio.add(bytes);
      },
      'response.audio.done': () async {
        _isAiSpeaking = false;
        _onAiSpeechEnd.add(null);
      },
      'response.text.delta': () async {
        Map<String, dynamic> map = data;
        String delta = map['delta'];
        _onAiText.add(delta);
      },
      'response.text.done': () async {
        _onAiTextEnd.add(null);
      },
    };
    handler = map[type];

    if (handler == null) {
      _logger.warn('No handler found for type: $type');
      return;
    }

    await handler();
  }

  @override
  Future<String?> getSessionToken() async {
    return null;
  }

  @override
  Map<String, dynamic> getSocketHeaders(Map<String, dynamic> baseHeaders) {
    return {};
  }
}
