import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:vit_gpt_dart_api/data/enums/role.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_session_config.dart';
import 'package:vit_gpt_dart_api/factories/create_log_group.dart';
import 'package:vit_gpt_dart_api/repositories/openai/openai_realtime_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SonioxOpenaiRealtimeRepository extends OpenaiRealtimeRepository {
  String sonioxTemporaryKey;

  final _logger = createGptDartLogger('SonioxOpenaiRealtimeRepository');
  //final _audioEncoder = AudioEncoder();

  bool isPressToTalk = false;

  WebSocketChannel? _sonioxSocket;

  final Map<String, Map<String, dynamic>> _sonioxTranscriptions = {};
  final Map<String, StringBuffer> _sonioxTokenBuffers = {};
  final Map<String, List<int>> _sonioxAudioBuffers = {};

  Timer? _sonioxKeepaliveTimer;
  static const Duration _sonioxKeepaliveInterval = Duration(seconds: 10);

  Timer? _sonioxEndpointTimer;
  Duration _sonioxEndpointDelay = Duration(milliseconds: 500);

  String? _currentSonioxItemId;

  bool _useSoniox = false;

  SonioxOpenaiRealtimeRepository({
    required this.sonioxTemporaryKey,
  });

  @override
  void commitUserAudio() {
    shouldCreateResponseAfterUserSpeechCommit = true;

    if (_useSoniox) {
      if (sonioxTemporaryKey.isNotEmpty && _sonioxSocket != null) {
        final finalizeMessage = jsonEncode({"type": "finalize"});
        _sonioxSocket?.sink.add(finalizeMessage);
        _logger.i('Sent manual finalization to Soniox');
      }
    } else {
      super.commitUserAudio();
    }
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    if (_useSoniox) {
      if (_currentSonioxItemId == null) {
        _currentSonioxItemId = _generateItemId();
        _sonioxTokenBuffers[_currentSonioxItemId!] = StringBuffer();
        _sonioxAudioBuffers[_currentSonioxItemId!] = [];
      }
      if (_currentSonioxItemId != null) {
        _sonioxAudioBuffers.putIfAbsent(_currentSonioxItemId!, () => []);
        _sonioxAudioBuffers[_currentSonioxItemId!]!.addAll(audioData);
      }
      if (sonioxTemporaryKey.isNotEmpty && _sonioxSocket != null) {
        _sonioxSocket?.sink.add(audioData);
      }
    } else {
      super.sendUserAudio(audioData);
    }
  }

  @override
  void close() {
    _sonioxKeepaliveTimer?.cancel();
    _sonioxKeepaliveTimer = null;
    _sonioxEndpointTimer?.cancel();
    _sonioxEndpointTimer = null;
    _sonioxSocket?.sink.close();
    _sonioxSocket = null;

    super.close();
    _sonioxTranscriptions.clear();
    _sonioxTokenBuffers.clear();
    _sonioxAudioBuffers.clear();
  }

  @override
  Future<void> onAfterOpen(RealtimeSessionConfig? config) async {
    final sonioxConfig = config as SonioxRealtimeSessionConfig?;
    _useSoniox = sonioxConfig?.useSoniox ?? false;
    isPressToTalk = sonioxConfig?.pressToTalk ?? false;

    if (sonioxConfig?.tdSilenceDuration != null) {
      _sonioxEndpointDelay =
          Duration(milliseconds: sonioxConfig!.tdSilenceDuration!);
    }

    if (_useSoniox && sonioxTemporaryKey.isNotEmpty) {
      await _openSonioxRealtimeConnection();
    }
  }

  @override
  Future<SonioxRealtimeSessionConfig?> getSessionToken() async => null;

  // MARK: Conversation item overrides

  @override
  Future<void> handleConversationItemCreated(Map<String, dynamic> data) async {
    if (_useSoniox && _sonioxTranscriptions[data['item']['id']] != null) {
      if (shouldCreateResponseAfterUserSpeechCommit) {
        sendMessage(isPreview
            ? {
                "type": "response.create",
                "response": {
                  "modalities": ["text", "audio"]
                },
              }
            : {
                "type": "response.create",
                "response": {
                  "output_modalities": ["audio"]
                },
              });
      }
    } else {
      await super.handleConversationItemCreated(data);
    }
  }

  @override
  Future<void> handleConversationItemDone(Map<String, dynamic> data) async {
    if (_useSoniox && _sonioxTranscriptions[data['item']['id']] != null) {
      if (shouldCreateResponseAfterUserSpeechCommit) {
        sendMessage(isPreview
            ? {
                "type": "response.create",
                "response": {
                  "modalities": ["text", "audio"]
                },
              }
            : {
                "type": "response.create",
                "response": {
                  "output_modalities": ["audio"]
                },
              });
      }
    } else {
      await super.handleConversationItemDone(data);
    }
  }

  @override
  Future<void> handleAudioBufferCommitted(String itemId) async {
    if (!_useSoniox) {
      await super.handleAudioBufferCommitted(itemId);
    }
    // In Soniox mode, response creation is triggered by Soniox finalization
  }

  // MARK: Soniox connection

  Future<void> _openSonioxRealtimeConnection() async {
    try {
      final sonioxUrl =
          Uri.parse('wss://stt-rt.soniox.com/transcribe-websocket');

      _logger.i('Connecting to Soniox realtime...');
      _sonioxSocket = WebSocketChannel.connect(sonioxUrl);

      final config = {
        'api_key': sonioxTemporaryKey,
        'model': 'stt-rt-v4',
        'audio_format': 'pcm_s16le',
        'sample_rate': 24000,
        'num_channels': 1,
        "language_hints": ["pt"],
        'enable_speaker_diarization': false,
        'enable_language_identification': false,
        if (!isPressToTalk) 'enable_endpoint_detection': true,
        if (!isPressToTalk)
          'max_endpoint_delay_ms': _sonioxEndpointDelay.inMilliseconds,
      };

      _sonioxSocket?.sink.add(jsonEncode(config));
      _logger.i('Sent Soniox configuration');

      _startSonioxKeepalive();

      _sonioxSocket?.stream.listen(
        (event) {
          _processSonioxRealtimeMessage(event);
        },
        onDone: () {
          _logger.i('Soniox connection closed');
          _sonioxKeepaliveTimer?.cancel();
          _sonioxKeepaliveTimer = null;
        },
        onError: (e) {
          _logger.e('Soniox WebSocket error: $e');
          _sonioxKeepaliveTimer?.cancel();
          _sonioxKeepaliveTimer = null;
        },
      );
    } catch (e) {
      _logger.e('Error opening Soniox realtime connection: $e');
    }
  }

  void _processSonioxRealtimeMessage(dynamic event) {
    try {
      final data = jsonDecode(event) as Map<String, dynamic>;

      if (data['error_code'] != null) {
        _logger.e(
            'Soniox error: ${data['error_code']} - ${data['error_message']}');
        return;
      }

      final tokens = data['tokens'] as List<dynamic>?;
      if (tokens != null && tokens.isNotEmpty) {
        for (var token in tokens) {
          final tokenMap = token as Map<String, dynamic>;
          final text = tokenMap['text'] as String?;
          final isFinal = tokenMap['is_final'] as bool? ?? false;

          if (text == null) continue;

          if (text == '<end>' && isFinal) {
            _handleSonioxEndpointDetection();
            continue;
          }

          if (text == '<fin>' && isFinal) {
            _handleSonioxFinalization();
            continue;
          }

          if (isFinal) {
            _sonioxTokenBuffers[_currentSonioxItemId!]!.write(text);
          } else {
            _cancelSonioxEndpointTimer();
          }
        }
      }

      final audioFinalProcMs = data['audio_final_proc_ms'];
      final audioTotalProcMs = data['audio_total_proc_ms'];
      if (audioFinalProcMs != null || audioTotalProcMs != null) {
        _logger.d(
            'Soniox progress - final: ${audioFinalProcMs}ms, total: ${audioTotalProcMs}ms');
      }
    } catch (e) {
      _logger.e('Error processing Soniox realtime message: $e');
    }
  }

  String _generateItemId() {
    return 'item_${Random().nextInt(10000000)}';
  }

  void _startSonioxKeepalive() {
    _sonioxKeepaliveTimer?.cancel();
    _sonioxKeepaliveTimer = Timer.periodic(_sonioxKeepaliveInterval, (timer) {
      if (_sonioxSocket != null) {
        final keepaliveMessage = jsonEncode({'type': 'keepalive'});
        _sonioxSocket?.sink.add(keepaliveMessage);
        _logger.d('Sent Soniox keepalive message');
      } else {
        timer.cancel();
      }
    });
    _logger.i(
        'Started Soniox keepalive timer (interval: ${_sonioxKeepaliveInterval.inSeconds}s)');
  }

  Future<void> _handleSonioxFinalization() async {
    if (_currentSonioxItemId == null) {
      _logger.w('Received finalization marker but no current item ID');
      return;
    }

    // Capture and immediately clear shared state BEFORE any async operations.
    // This prevents new speech turns from reusing the same item ID while
    // MP3 encoding is in progress (which was causing multi-turn text batching).
    final itemId = _currentSonioxItemId!;
    _currentSonioxItemId = null;
    final transcript = _sonioxTokenBuffers.remove(itemId)?.toString() ?? '';
    // final audioBytes = _sonioxAudioBuffers.remove(itemId);

    if (transcript.isEmpty) {
      _logger.w('Finalization complete but transcript is empty for $itemId');
      return;
    }

    _logger.i('Soniox finalization complete for $itemId: $transcript');

    _sonioxTranscriptions[itemId] = {
      'text': transcript,
      'isFinal': true,
    };

    //List<int>? mp3AudioBytes;
    // if (audioBytes != null) {
    //   try {
    //     final stopwatch = Stopwatch()..start();
    //     final mp3Data = await _audioEncoder.encodePcmToMp3(
    //       pcmData: Uint8List.fromList(audioBytes),
    //       sampleRate: 24000,
    //       numChannels: 1,
    //     );
    //     stopwatch.stop();
    //     mp3AudioBytes = mp3Data.toList();
    //     _logger.i(
    //         'Converted Soniox audio to MP3 in ${stopwatch.elapsedMilliseconds}ms (${audioBytes.length} PCM bytes -> ${mp3AudioBytes.length} MP3 bytes)');
    //     onMp3EncodingCompleted(
    //         stopwatch.elapsed, audioBytes.length, mp3AudioBytes.length);
    //   } catch (e) {
    //     _logger.e('Failed to convert Soniox audio to MP3: $e');
    //     mp3AudioBytes = audioBytes;
    //   }
    // }

    var transcriptionEnd = TranscriptionEnd(
      id: itemId,
      content: transcript,
      role: Role.user,
      contentIndex: 0,
      previousItemId: itemIdWithPreviousItemId[itemId],
      audioBytes: null,
    );
    onTranscriptionEndController.add(transcriptionEnd);

    var msg = <String, dynamic>{
      "type": "conversation.item.create",
      'item': {
        'id': itemId,
        'type': 'message',
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text': transcript,
          }
        ],
      },
    };
    sendMessage(msg);
  }

  void _handleSonioxEndpointDetection() {
    _logger.i('Soniox endpoint detected');

    if (!isPressToTalk) {
      _logger.i(
          'Starting endpoint timer (${_sonioxEndpointDelay.inSeconds}s) for auto-commit');

      _cancelSonioxEndpointTimer();

      _sonioxEndpointTimer = Timer(_sonioxEndpointDelay, () {
        _logger.i('Endpoint timer completed, committing user audio');
        commitUserAudio();
      });
    }
  }

  /// Called after MP3 encoding completes for a user speech turn.
  /// Override in subclasses to report encoding metrics (e.g. to a server).
  void onMp3EncodingCompleted(Duration duration, int pcmBytes, int mp3Bytes) {}

  void _cancelSonioxEndpointTimer() {
    if (_sonioxEndpointTimer != null && _sonioxEndpointTimer!.isActive) {
      _logger.d('Cancelling endpoint timer (user still speaking)');
      _sonioxEndpointTimer?.cancel();
      _sonioxEndpointTimer = null;
    }
  }
}
