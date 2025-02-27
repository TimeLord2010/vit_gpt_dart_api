import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_dart_api/repositories/handlers/job_sequencer.dart';
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
  final _onRawAiAudio = StreamController<String>.broadcast();
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
  Stream<String> get onRawAiAudio => _onRawAiAudio.stream;

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
  bool _isUserSpeaking = false;

  bool _isConnected = false;

  /// I did find that avoiding as much processing as possible on
  /// the main thread when receiving audio data is the best way to avoid
  /// crashes. When this value is set to false, the audio data is decoded from
  /// base64 on the main thread, which can cause crashes if the audio data is
  /// being received at a high rate or is too large.
  ///
  /// If thats not possible in your case, you can set this to false and
  /// decode the audio data on the main thread and possibly send to your player
  /// or choice.
  bool _streamAiAudioAsText = true;

  /// Garantees that the audio player receives the audio data in the correct
  /// order
  final aiAudioJobs = JobSequencer();

  // MARK: Properties

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isAiSpeaking => _isAiSpeaking;

  set isAiSpeaking(bool value) {
    if (!value) {
      aiAudioJobs.reset();
    }
    _isAiSpeaking = value;
  }

  @override
  bool get isUserSpeaking => _isUserSpeaking;

  @override
  Uri? get uri => null;

  @override
  bool get streamAiAudioAsText => _streamAiAudioAsText;

  set streamAiAudioAsText(bool value) {
    _streamAiAudioAsText = value;
  }

  // MARK: METHODS

  @override
  void stopAiSpeech() {
    var mapData = {"type": "response.cancel"};
    var strData = jsonEncode(mapData);
    socket?.sink.add(strData);
  }

  @override
  void commitUserAudio() {
    var mapData = {
      "type": "input_audio_buffer.commit",
    };
    var strData = jsonEncode(mapData);
    socket?.sink.add(strData);
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
    _onError.close();

    _onUserText.close();
    _onUserSpeechBegin.close();
    _onUserSpeechEnd.close();

    _onAiText.close();
    _onAiAudio.close();
    _onAiTextEnd.close();
    _onAiSpeechBegin.close();
    _onAiSpeechEnd.close();
    _onRawAiAudio.close();

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

    var opts = getSocketHeaders({
      'Authorization': 'Bearer $token',
      'OpenAI-Beta': 'realtime=v1',
    });

    var s = socket = IOWebSocketChannel.connect(
      url,
      headers: opts,
    );

    s.stream.listen(
      (event) async {
        String rawData = event;
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
        _logger.info('Session created');
        sessionConfig = data['session'];
        _isConnected = true;
        _onConnected.add(null);
      },
      'session.updated': () async {
        _logger.info('Session updated');
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
            num seconds = limit['reset_seconds'];
            _onRemaingTimeUpdated.add(Duration(
              seconds: seconds.toInt(),
            ));
          }
        }
      },

      // User events
      'input_audio_buffer.speech_started': () async {
        _onUserSpeechBegin.add(null);
        _isUserSpeaking = true;
      },
      'input_audio_buffer.speech_stopped': () async {
        _onUserSpeechEnd.add(null);
        _isUserSpeaking = false;
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
        if (!isAiSpeaking) {
          _onAiSpeechBegin.add(null);
        }
        isAiSpeaking = true;

        // Getting and sending audio data
        String base64Data = data['delta'];

        if (streamAiAudioAsText) {
          _onRawAiAudio.add(base64Data);
        } else {
          var bytes = base64Decode(base64Data);
          _onAiAudio.add(bytes);
        }
      },
      'response.audio.done': () async {
        isAiSpeaking = false;
        _onAiSpeechEnd.add(null);
      },
      'response.text.delta': () async {
        Map<String, dynamic> map = data;
        String delta = map['delta'];

        int contentIndex = (map['content_index'] as num).toInt();

        aiAudioJobs.addJob(Job(
          index: contentIndex,
          fn: () async {
            _onAiText.add(delta);
            await Future.delayed(const Duration(milliseconds: 25));
          },
        ));
      },
      'response.text.done': () async {
        _onAiTextEnd.add(null);
      },
      'response.cancelled': () async {
        // Sent when [stopAiSpeech] is called.

        isAiSpeaking = false;
        _onAiSpeechEnd.add(null);
      },
    };
    handler = map[type];

    if (handler == null) {
      _logger.warn('No handler found for type: $type');
      return;
    }
    _logger.debug('Processing server message of type: $type');

    try {
      await handler();
    } on Exception catch (e) {
      _onError.add(e);
      _logger.error('Error while processing $type: $e');
      _logger.error('Received data: $data');
    }
  }

  @override
  Future<String?> getSessionToken() async {
    return null;
  }

  @override
  Map<String, dynamic> getSocketHeaders(Map<String, dynamic> baseHeaders) {
    return {
      ...baseHeaders,
    };
  }
}
