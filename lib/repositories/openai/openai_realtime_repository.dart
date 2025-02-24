import 'dart:async';
import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/usecases/index.dart';
import 'package:vit_logger/vit_logger.dart';

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

  io.Socket? socket;
  String? eventId;
  bool _isAiSpeaking = false;
  final bool _isUserSpeaking = false;

  // MARK: Properties

  @override
  bool get isAiSpeaking => _isAiSpeaking;

  @override
  bool get isUserSpeaking => _isUserSpeaking;

  @override
  String? get apiUrl => null;

  // MARK: METHODS

  @override
  void commitUserAudio() {
    socket?.emit('input_audio_buffer.commit', {
      "type": "input_audio_buffer.commit",
    });
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    _logger.debug('Sending user audio');
    socket?.emit('input_audio_buffer.append', {
      "type": "input_audio_buffer.append",
      "audio": String.fromCharCodes(audioData),
    });
  }

  @override
  void close() {
    socket?.close();
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
    socket?.close();

    String? token;

    token = await getSessionToken();

    token ??= await getApiToken();

    if (token == null) {
      _onError.add(Exception('No token found'));
      return;
    }

    String url = apiUrl ?? 'https://api.openai.com/v1/realtime';

    socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'Authorization': 'Bearer $token',
      'OpenAI-Beta': 'realtime=v1',
    });

    socket?.onConnect((_) => _onConnected.add(null));

    socket?.onDisconnect((_) => _onDisconnected.add(null));

    // User events

    socket?.on('input_audio_buffer.speech_started', (_) {
      _onUserSpeechBegin.add(null);
    });

    socket?.on('input_audio_buffer.speech_stopped', (_) {
      _onUserSpeechEnd.add(null);
    });

    socket?.on('conversation.item.create', (data) {
      _logger.info('Conversation item created');
      Map<String, dynamic> map = data;
      List<Map<String, dynamic>> items = map['items'];

      for (var item in items) {
        String type = item['type'];
        String role = item['role'];
        _logger.info('Type: $type. Role: $role');
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
    });

    // Ai events

    socket?.on('response.text.delta', (data) {
      Map<String, dynamic> map = data;
      String delta = map['delta'];
      _onAiText.add(delta);
    });

    socket?.on('response.text.done', (_) {
      _onAiTextEnd.add(null);
    });

    socket?.on('response.audio.delta', (data) {
      // Updating ai speaking status
      if (!_isAiSpeaking) {
        _onAiSpeechBegin.add(null);
      }
      _isAiSpeaking = true;

      // Getting and sending audio data
      Map<String, dynamic> map = data;
      assert(map['type'] == 'response.audio.delta');
      String base64Data = map['delta'];
      var bytes = Uint8List.fromList(base64Data.codeUnits);
      _onAiAudio.add(bytes);
    });

    socket?.on('response.audio.done', (_) {
      _isAiSpeaking = false;
      _onAiSpeechEnd.add(null);
    });

    // System events

    socket?.on('rate_limits.updated', (data) {
      Map<String, dynamic> map = data;
      var rateLimits = List<Map<String, dynamic>>.from(map['rate_limits']);

      for (var limit in rateLimits) {
        if (limit['name'] == 'requests') {
          _onRemainingRequestsUpdated.add(limit['remaining']);
        } else if (limit['name'] == 'tokens') {
          _onRemaingTimeUpdated.add(Duration(seconds: limit['reset_seconds']));
        }
      }
    });

    socket?.open();
  }

  @override
  Future<String?> getSessionToken() async {
    return null;
  }
}
