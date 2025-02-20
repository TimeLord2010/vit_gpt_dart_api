import 'dart:async';
import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';

class OpenaiRealtimeRepository extends RealtimeModel {
  io.Socket? socket;

  // Stream controllers
  final _onError = StreamController<Exception>.broadcast();
  final _onConnected = StreamController<void>.broadcast();
  final _onDisconnected = StreamController<void>.broadcast();
  final _onUserText = StreamController<String>.broadcast();
  final _onAiText = StreamController<String>.broadcast();
  final _onAiAudio = StreamController<Uint8List>.broadcast();
  final _onUserAudioCommited = StreamController<void>.broadcast();
  final _onUserSpeechBegin = StreamController<void>.broadcast();
  final _onUserSpeechEnd = StreamController<void>.broadcast();
  final _onAiSpeechBegin = StreamController<void>.broadcast();
  final _onAiSpeechEnd = StreamController<void>.broadcast();
  final _onRemainingRequestsUpdated = StreamController<int>.broadcast();
  final _onRemaingTimeUpdated = StreamController<Duration>.broadcast();

  @override
  Stream<Uint8List> get onAiAudio => _onAiAudio.stream;

  @override
  Stream<String> get onAiText => _onAiText.stream;

  @override
  Stream<void> get onConnectionClose => _onDisconnected.stream;

  @override
  Stream<void> get onConnectionOpen => _onConnected.stream;

  @override
  Stream<Exception> get onError => _onError.stream;

  @override
  Stream<String> get onUserText => _onUserText.stream;

  @override
  Stream<void> get onUserAudioCommited => _onUserAudioCommited.stream;

  @override
  Stream<void> get onUserSpeechBegin => _onUserSpeechBegin.stream;

  @override
  Stream<void> get onUserSpeechEnd => _onUserSpeechEnd.stream;

  @override
  Stream<void> get onAiSpeechBegin => _onAiSpeechBegin.stream;

  @override
  Stream<void> get onAiSpeechEnd => _onAiSpeechEnd.stream;

  @override
  Stream<Duration> get onRemaingTimeUpdated => _onRemaingTimeUpdated.stream;

  @override
  Stream<int> get onRemainingRequestsUpdated {
    return _onRemainingRequestsUpdated.stream;
  }

  @override
  void commitUserAudio() {
    // TODO: implement commitUserAudio
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    // TODO: implement sendUserAudio
  }

  @override
  void close() {
    socket?.close();
    socket = null;

    _onConnected.close();
    _onDisconnected.close();
    _onUserText.close();
    _onAiText.close();
    _onAiAudio.close();
    _onError.close();
    _onUserAudioCommited.close();
    _onUserSpeechBegin.close();
    _onUserSpeechEnd.close();
  }

  @override
  void open() {
    close();

    socket = io.io('https://api.openai.com/v1/realtime', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket?.onConnect((_) => _onConnected.add(null));

    socket?.onDisconnect((_) => _onDisconnected.add(null));

    // User events

    // Ai events
    socket?.on('response.audio.delta', (data) {
      Map<String, dynamic> map = data;
      assert(map['type'] == 'response.audio.delta');
      String base64Data = map['delta'];
      var bytes = Uint8List.fromList(base64Data.codeUnits);
      _onAiAudio.add(bytes);
    });

    socket?.on('response.audio.done', (_) {
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
}
