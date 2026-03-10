import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/usecases/local_storage/api_token/get_api_token.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:vit_gpt_dart_api/data/enums/role.dart';
import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_response.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_start.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/factories/create_log_group.dart';
import 'package:vit_gpt_dart_api/repositories/base_realtime_repository.dart';
import 'package:vit_gpt_dart_api/usecases/audio/encoder/audio_encoder.dart';

class OpenaiRealtimeRepository extends BaseRealtimeRepository {
  String sonioxTemporaryKey;

  final _logger = createGptDartLogger('OpenAiRealtimeRepository');
  final _audioEncoder = AudioEncoder();

  static const Duration initialMessagesTimeout = Duration(seconds: 30);

  Iterable<Message> get sendableInitialMessages {
    List<Message> initialMsgs = initialMessages ?? [];
    return initialMsgs.where((msg) {
      return msg.text.trim().isNotEmpty;
    });
  }

  @override
  Iterable<Message> get sentInitialMessages {
    return sendableInitialMessages.where((x) {
      var key = _messageKey(x.role, x.text);
      return _sentInitialMessages.contains(key);
    });
  }

  bool isPreview = false;
  bool useSoniox = false;
  bool isPressToTalk = false;

  WebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  final _sentInitialMessages = <String>{};

  final _aiTextResponseBuffer = StringBuffer();

  /// Maps itemId -> previousItemId.
  ///
  /// Important: `previous_item_id` may legitimately be `null` (e.g. first item)
  /// or may be missing depending on event ordering, so we keep nullable values
  /// and use `containsKey` when we need to know whether we have already
  /// received a linking event.
  final Map<String, String?> itemIdWithPreviousItemId = {};

  Timer? _initialMessagesTimeoutTimer;

  bool shouldCreateResponseAfterUserSpeechCommit = false;

  final Map<String, List<int>> _userAudioBuffers = {};
  final Map<String, List<int>> _aiAudioBuffers = {};
  String? _currentUserItemId;
  String? _currentAiResponseId;

  WebSocketChannel? _sonioxSocket;

  final Map<String, Map<String, dynamic>> _sonioxTranscriptions = {};

  final Map<String, StringBuffer> _sonioxTokenBuffers = {};

  final Map<String, List<int>> _sonioxAudioBuffers = {};

  /// Pending Soniox finalizations waiting for OpenAI to confirm/attach
  /// `previous_item_id`.
  ///
  /// We only emit `onTranscriptionEnd` for user messages after we have at least
  /// the server-side `conversation.item.added` event, otherwise the UI ordering
  /// (itemId/previousItemId) becomes unreliable.
  final Map<String, ({String transcript, List<int>? audioBytes})>
      _pendingSonioxFinalizations = {};

  /// Fallback timers so we don't lose user bubbles if OpenAI never sends
  /// `conversation.item.added/done` (or if they arrive very late on mobile).
  final Map<String, Timer> _pendingSonioxFinalizationTimers = {};

  static const Duration _pendingSonioxFinalizationTimeout =
      Duration(seconds: 2);

  Timer? _sonioxKeepaliveTimer;
  static const Duration _sonioxKeepaliveInterval = Duration(seconds: 10);

  Timer? _sonioxEndpointTimer;
  Duration _sonioxEndpointDelay = Duration(milliseconds: 500);

  int _sonioxItemSequence = 0;

  OpenaiRealtimeRepository({
    required this.sonioxTemporaryKey,
  });

  @override
  void stopAiSpeech() {
    var mapData = {"type": "response.cancel"};
    var strData = jsonEncode(mapData);
    socket?.sink.add(strData);
  }

  @override
  void commitUserAudio() async {
    shouldCreateResponseAfterUserSpeechCommit = true;

    if (useSoniox) {
      if (sonioxTemporaryKey.isNotEmpty && _sonioxSocket != null) {
        final finalizeMessage = jsonEncode({"type": "finalize"});
        _sonioxSocket?.sink.add(finalizeMessage);
        _logger.i('Sent manual finalization to Soniox');
      }
    } else {
      sendMessage({
        "type": "input_audio_buffer.commit",
      });
    }
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    if (useSoniox) {
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
      _currentUserItemId ??= '_temp_buffer';
      _userAudioBuffers.putIfAbsent(_currentUserItemId!, () => []);
      _userAudioBuffers[_currentUserItemId!]!.addAll(audioData);

      var mapData = {
        "type": "input_audio_buffer.append",
        "audio": base64Encode(audioData),
      };
      var strData = jsonEncode(mapData);
      socket?.sink.add(strData);
    }
  }

  @override
  void close() {
    _initialMessagesTimeoutTimer?.cancel();
    _initialMessagesTimeoutTimer = null;
    socket?.sink.close();
    socket = null;

    _sonioxKeepaliveTimer?.cancel();
    _sonioxKeepaliveTimer = null;
    _sonioxEndpointTimer?.cancel();
    _sonioxEndpointTimer = null;
    _sonioxSocket?.sink.close();
    _sonioxSocket = null;

    super.close();
    itemIdWithPreviousItemId.clear();
    _sentInitialMessages.clear();
    _sonioxTranscriptions.clear();
    _sonioxTokenBuffers.clear();
    _sonioxAudioBuffers.clear();
    _pendingSonioxFinalizations.clear();
    for (final t in _pendingSonioxFinalizationTimers.values) {
      t.cancel();
    }
    _pendingSonioxFinalizationTimers.clear();
    _userAudioBuffers.clear();
    _aiAudioBuffers.clear();
    _currentUserItemId = null;
    _currentAiResponseId = null;
  }

  @override
  Future<void> open() async {
    socket?.sink.close();
    String? token;

    final sessionResponse = await getSessionToken();

    token = sessionResponse?.token;
    token ??= await getApiToken();

    if (token == null) {
      onErrorController.add(Exception('No token found'));
      return;
    }

    useSoniox = sessionResponse?.useSoniox ?? false;
    isPressToTalk = sessionResponse?.pressToTalk ?? false;

    if (sessionResponse?.tdSilenceDuration != null) {
      _sonioxEndpointDelay =
          Duration(milliseconds: sessionResponse!.tdSilenceDuration!);
    }

    var url = uri ??
        Uri(
          scheme: 'wss',
          host: 'api.openai.com',
          path: '/v1/realtime',
        );

    final protocols = [
      "realtime",
      "openai-insecure-api-key.$token",
    ];

    isPreview = sessionResponse?.model.contains('preview') ?? true;

    if (isPreview) {
      protocols.add("openai-beta.realtime-v1");
    }

    var s = socket = WebSocketChannel.connect(
      url,
      protocols: protocols,
    );

    s.stream.listen(
      (event) async {
        String rawData = event;
        Map<String, dynamic> data = jsonDecode(rawData);
        onSocketDataController.add(data);
        String type = data['type'];
        await _processServerMessage(type, data, isPreview);
      },
      onDone: () {
        _logger.i('Connection closed');
        onDisconnectedController.add(null);
      },
      onError: (e) {
        _logger.e('Error: $e');
        onErrorController.add(e);
      },
    );

    if (useSoniox && sonioxTemporaryKey.isNotEmpty) {
      await _openSonioxRealtimeConnection();
    }
  }

  Future<void> _processServerMessage(
    String type,
    Map<String, dynamic> data,
    bool isPreview,
  ) async {
    Future<void> Function()? handler;

    var map = <String, Future<void> Function()>{
      'error': () async {
        Map<String, dynamic> error = data['error'];
        String message = error['message'];
        onErrorController.add(Exception(message));
      },
      'session.created': () async {
        _logger.i('Session created');
        sessionConfig = data['session'];

        try {
          List<Message> initialMsgs = sendableInitialMessages.toList();
          _logger.i(
              'Sendable initial messages: ${initialMsgs.map((x) => x.text).join(', ')}');
          if (initialMsgs.isEmpty) return;

          setIsSendingInitialMessages(true);

          _initialMessagesTimeoutTimer = Timer(initialMessagesTimeout, () {
            _logger.w('Initial messages timeout reached, closing connection');
            close();
          });

          var someHaveId = initialMsgs.any((x) => x.id != null);
          for (int i = 0; i < initialMsgs.length; i++) {
            Message? previousMsg = i > 0 ? initialMsgs[i - 1] : null;
            String? previousMsgId = previousMsg?.id;
            Message message = initialMsgs[i];
            var role = message.role;
            var msg = <String, dynamic>{
              "type": "conversation.item.create",
              if (previousMsgId != null) 'previous_item_id': previousMsgId,
              'item': {
                if (message.id != null) 'id': message.id,
                'type': 'message',
                'role': role.name,
                'content': [
                  {
                    'type': role == Role.assistant
                        ? (isPreview ? 'text' : 'output_text')
                        : 'input_text',
                    'text': message.text,
                  }
                ],
              },
            };
            sendMessage(msg);
            _logger.d('Created manual message: ${msg.prettyJSON}');

            if (someHaveId) await Future.delayed(Duration(milliseconds: 100));
          }

          await Future.delayed(Duration(milliseconds: 200));

          final previewConfig = {
            "type": "response.create",
            "response": {
              "modalities": ["text", "audio"]
            },
          };

          final stableConfig = {
            "type": "response.create",
            "response": {
              "output_modalities": ["audio"]
            }
          };

          sendMessage(isPreview ? previewConfig : stableConfig);
        } on Exception catch (e) {
          _logger.e(e);
          setIsSendingInitialMessages(false);
        } finally {
          isConnected = true;
          onConnectedController.add(null);
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
            onRemainingRequestsUpdatedController.add(amount.toInt());
          } else if (limit['name'] == 'tokens') {
            num amount = limit['remaining'];
            onRemainingTokensUpdatedController.add(amount.toInt());
          }
        }
      },
      'conversation.item.created': () async {
        if (useSoniox && _sonioxTranscriptions[data['item']['id']] != null) {
          if (shouldCreateResponseAfterUserSpeechCommit) {
            final previewConfig = {
              "type": "response.create",
              "response": {
                "modalities": ["text", "audio"]
              },
            };

            final stableConfig = {
              "type": "response.create",
              "response": {
                "output_modalities": ["audio"]
              },
            };

            sendMessage(isPreview ? previewConfig : stableConfig);
            shouldCreateResponseAfterUserSpeechCommit = false;
          }
        } else {
          _confirmInitialMessage(data);
          onConversationItemCreatedController.add(data);
        }
      },
      'conversation.item.added': () async {
        final itemId = data['item']['id'] as String;
        final dynamic prev = data['previous_item_id'];
        // Never overwrite a previously known value with null.
        if (prev != null || !itemIdWithPreviousItemId.containsKey(itemId)) {
          itemIdWithPreviousItemId[itemId] = prev as String?;
        }

        // If this item corresponds to a Soniox user message we created, now we
        // have the best chance of having a stable `previous_item_id` to attach.
        final pending = _pendingSonioxFinalizations.remove(itemId);
        if (pending != null) {
          _pendingSonioxFinalizationTimers.remove(itemId)?.cancel();
          onTranscriptionEndController.add(TranscriptionEnd(
            id: itemId,
            content: pending.transcript,
            role: Role.user,
            contentIndex: 0,
            previousItemId: itemIdWithPreviousItemId[itemId],
            audioBytes: pending.audioBytes,
          ));
        }
      },
      'conversation.item.done': () async {
        final itemId = data['item']['id'] as String;
        // Some clients observed `previous_item_id` coming as null here even
        // when it was present in `conversation.item.added`. We still store the
        // value to mark the item as seen.
        final dynamic prev = data['previous_item_id'];
        // Never overwrite a previously known value with null.
        if (prev != null || !itemIdWithPreviousItemId.containsKey(itemId)) {
          itemIdWithPreviousItemId[itemId] = prev as String?;
        }

        // Same draining logic as in `conversation.item.added` to be resilient
        // to event reordering.
        final pending = _pendingSonioxFinalizations.remove(itemId);
        if (pending != null) {
          _pendingSonioxFinalizationTimers.remove(itemId)?.cancel();
          onTranscriptionEndController.add(TranscriptionEnd(
            id: itemId,
            content: pending.transcript,
            role: Role.user,
            contentIndex: 0,
            previousItemId: itemIdWithPreviousItemId[itemId],
            audioBytes: pending.audioBytes,
          ));
        }

        if (useSoniox && _sonioxTranscriptions[data['item']['id']] != null) {
          // No-op: for Soniox we trigger `response.create` on
          // `conversation.item.created` to avoid double-creating responses.

          // Prevent unbounded growth (mobile long sessions) once the item is
          // fully done.
          _sonioxTranscriptions.remove(data['item']['id']);
        } else {
          _confirmInitialMessage(data);
          onConversationItemCreatedController.add(data);
        }
      },
      'input_audio_buffer.speech_started': () async {
        String newItemId = data['item_id'];

        if (_currentUserItemId == '_temp_buffer' &&
            _userAudioBuffers.containsKey('_temp_buffer')) {
          _userAudioBuffers[newItemId] =
              _userAudioBuffers['_temp_buffer'] ?? [];
          _userAudioBuffers.remove('_temp_buffer');
        } else {
          _userAudioBuffers[newItemId] = [];
        }

        _currentUserItemId = newItemId;
        onSpeechStartController.add(SpeechStart(
          id: data['item_id'],
          role: Role.user,
        ));
        isUserSpeaking = true;
      },
      'input_audio_buffer.speech_stopped': () async {
        onSpeechEndController.add(SpeechEnd(
          id: data['item_id'],
          role: Role.user,
          done: false,
        ));
        isUserSpeaking = false;
      },
      'input_audio_buffer.committed': () async {
        String itemId = data['item_id'];

        onSpeechEndController.add(SpeechEnd(
          id: itemId,
          role: Role.user,
          done: true,
        ));
        isUserSpeaking = false;

        _currentUserItemId = null;

        if (!useSoniox && shouldCreateResponseAfterUserSpeechCommit) {
          final previewConfig = {
            "type": "response.create",
            "response": {
              "modalities": ["text", "audio"]
            },
          };

          final stableConfig = {
            "type": "response.create",
            "response": {
              "output_modalities": ["audio"]
            },
          };

          sendMessage(isPreview ? previewConfig : stableConfig);
          shouldCreateResponseAfterUserSpeechCommit = false;
        }
      },
      'conversation.item.input_audio_transcription.completed': () async {
        String itemId = data['item_id'];
        String content = data['transcript'];

        List<int>? audioBytes = _userAudioBuffers[itemId];

        List<int>? mp3AudioBytes;
        if (audioBytes != null) {
          try {
            final mp3Data = await _audioEncoder.encodePcmToMp3(
              pcmData: Uint8List.fromList(audioBytes),
              sampleRate: 24000,
              numChannels: 1,
            );
            mp3AudioBytes = mp3Data.toList();
            _logger.i(
                'Converted user audio to MP3 (${audioBytes.length} PCM bytes -> ${mp3AudioBytes.length} MP3 bytes)');
          } catch (e) {
            _logger.e('Failed to convert user audio to MP3: $e');
            mp3AudioBytes = audioBytes;
          }
        }

        var transcriptionEnd = TranscriptionEnd(
          id: itemId,
          content: content,
          role: Role.user,
          contentIndex: (data['content_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[itemId],
          audioBytes: mp3AudioBytes,
        );
        onTranscriptionEndController.add(transcriptionEnd);

        _userAudioBuffers.remove(itemId);
      },
      'response.audio.delta': () async {
        String responseId = data['response_id'];

        if (!isAiSpeaking) {
          _currentAiResponseId = responseId;
          _aiAudioBuffers[responseId] = [];
          onSpeechStartController.add(SpeechStart(
            id: responseId,
            role: Role.assistant,
          ));
        }
        isAiSpeaking = true;

        String base64Data = data['delta'];
        List<int> audioBytes = base64Decode(base64Data);
        _aiAudioBuffers[responseId]?.addAll(audioBytes);

        onSpeechController.add(SpeechItem<String>(
          id: responseId,
          audioData: base64Data,
          role: Role.assistant,
          contentIndex: data['content_index'],
        ));
      },
      'response.output_audio.delta': () async {
        String responseId = data['response_id'];

        if (!isAiSpeaking) {
          _currentAiResponseId = responseId;
          _aiAudioBuffers[responseId] = [];
          onSpeechStartController.add(SpeechStart(
            id: responseId,
            role: Role.assistant,
          ));
        }
        isAiSpeaking = true;

        String base64Data = data['delta'];
        List<int> audioBytes = base64Decode(base64Data);
        _aiAudioBuffers[responseId]?.addAll(audioBytes);

        onSpeechController.add(SpeechItem<String>(
          id: responseId,
          audioData: base64Data,
          role: Role.assistant,
          contentIndex: data['content_index'],
        ));
      },
      'response.audio.done': () async {
        isAiSpeaking = false;
        onSpeechEndController.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
          done: true,
        ));
      },
      'response.output_audio.done': () async {
        isAiSpeaking = false;
        onSpeechEndController.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
          done: true,
        ));
      },
      'conversation.item.input_audio_transcription.delta': () async {
        var item = TranscriptionItem.fromMap(data, role: Role.user);
        onTranscriptionItemController.add(item);
      },
      'response.audio_transcript.done': () async {
        String itemId = data['item_id'];
        onTranscriptionEndController.add(TranscriptionEnd(
          id: itemId,
          role: Role.assistant,
          content: _aiTextResponseBuffer.toString(),
          contentIndex: (data['content_index'] as num).toInt(),
          outputIndex: (data['output_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[itemId],
        ));
        _aiTextResponseBuffer.clear();
      },
      'response.output_audio_transcript.done': () async {
        final String itemId = data['item_id'];

        // Wait briefly for `conversation.item.added/done` to arrive and fill the
        // linking map. We must not wait forever because OpenAI may send
        // `previous_item_id` as null in some cases.
        final start = DateTime.now();
        while (!itemIdWithPreviousItemId.containsKey(itemId) &&
            DateTime.now().difference(start) < const Duration(seconds: 2)) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        onTranscriptionEndController.add(TranscriptionEnd(
          id: itemId,
          role: Role.assistant,
          content: _aiTextResponseBuffer.toString(),
          contentIndex: (data['content_index'] as num).toInt(),
          outputIndex: (data['output_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[itemId],
        ));
        _aiTextResponseBuffer.clear();
      },
      'response.audio_transcript.delta': () async {
        var item = TranscriptionItem.fromMap(data, role: Role.assistant);
        _aiTextResponseBuffer.write(item.text);
        onTranscriptionItemController.add(item);
      },
      'response.output_audio_transcript.delta': () async {
        var item = TranscriptionItem.fromMap(data, role: Role.assistant);
        _aiTextResponseBuffer.write(item.text);
        onTranscriptionItemController.add(item);
      },
      'response.cancelled': () async {
        isAiSpeaking = false;
        onSpeechEndController.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
          done: false,
        ));
      },
      'response.done': () async {
        var map = data['response'];
        final String responseId = map['id'];
        var output = map['output'] as List?;
        if (output != null && output.isNotEmpty) {
          map['previousItemId'] = itemIdWithPreviousItemId[output[0]['id']];
        }

        // Always attach audio bytes using the response id from the event.
        // Using `_currentAiResponseId` is unsafe under event reordering and can
        // cause audio from another response to be attached.
        if (_aiAudioBuffers[responseId] != null) {
          List<int> audioBytes = _aiAudioBuffers[responseId]!;

          List<int>? mp3AudioBytes;
          try {
            final mp3Data = await _audioEncoder.encodePcmToMp3(
              pcmData: Uint8List.fromList(audioBytes),
              sampleRate: 24000,
              numChannels: 1,
            );
            mp3AudioBytes = mp3Data.toList();
            _logger.i(
                'Converted response audio to MP3 (${audioBytes.length} PCM bytes -> ${mp3AudioBytes.length} MP3 bytes)');
          } catch (e) {
            _logger.e('Failed to convert response audio to MP3: $e');
            mp3AudioBytes = audioBytes;
          }

          map['audioBytes'] = mp3AudioBytes;
        }

        var response = RealtimeResponse.fromMap(map);
        onResponseController.add(response);

        _aiAudioBuffers.remove(responseId);
        if (_currentAiResponseId == responseId) {
          _currentAiResponseId = null;
        }
      },
    };
    handler = map[type];

    if (handler == null) {
      _logger.w('No handler found for type: $type. Data: $data');
      return;
    }

    try {
      _logger.d('Processing type $type');
      await handler();
    } catch (e) {
      if (e is Exception) {
        onErrorController.add(e);
      } else {
        onErrorController.add(Exception(e.toString()));
      }
      _logger.e('Error while processing $type. Received data: $data', error: e);
      _logger.e('Error: ${e.toString()}');
    }
  }

  Future<
      ({
        String token,
        String model,
        bool useSoniox,
        bool pressToTalk,
        int? tdSilenceDuration
      })?> getSessionToken() async => null;

  @override
  void sendMessage(Map<String, dynamic> map) {
    var strData = jsonEncode(map);
    socket?.sink.add(strData);
  }

  void _confirmInitialMessage(Map<String, dynamic> data) {
    var initialMessages = this.initialMessages ?? [];
    if (initialMessages.isEmpty) {
      return;
    }

    Map<String, dynamic> item = data['item'];
    dynamic type = item['type'];
    if (type is String && type != 'message') {
      return;
    }

    List content = item['content'];
    var onlyItem = content.firstWhereOrNull((x) {
      if (x is Map<String, dynamic> && x['text'] is String) {
        return true;
      }
      return false;
    });
    if (onlyItem == null) {
      return;
    }
    String text = onlyItem['text'];

    Role role = Role.fromValue(item['role']);
    var foundInitialMessage = initialMessages.firstWhereOrNull((x) {
      return x.role == role && x.text == text;
    });
    if (foundInitialMessage == null) {
      return;
    }

    String messageKey = _messageKey(role, text);
    _sentInitialMessages.add(messageKey);
    _logger.d('Confirmed message has been sent: $messageKey');

    List<Message> nonEmptyInitialMessages = initialMessages.where((msg) {
      return msg.text.trim().isNotEmpty;
    }).toList();

    bool allMessagesSent = nonEmptyInitialMessages.every((msg) {
      String msgKey = '${msg.role.name}:${msg.text}';
      return _sentInitialMessages.contains(msgKey);
    });

    if (allMessagesSent) {
      _initialMessagesTimeoutTimer?.cancel();
      _initialMessagesTimeoutTimer = null;
      setIsSendingInitialMessages(false);
    }
  }

  String _messageKey(Role role, String text) {
    return '${role.name}:$text';
  }

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
            final currentId = _currentSonioxItemId;
            if (currentId == null) {
              _logger.w('Received final token but no current Soniox itemId');
              continue;
            }
            _sonioxTokenBuffers.putIfAbsent(currentId, () => StringBuffer());
            _sonioxTokenBuffers[currentId]!.write(text);
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

  String? _currentSonioxItemId;

  String _generateItemId() {
    // Avoid collisions and make IDs monotonic-ish for easier debugging.
    final ts = DateTime.now().microsecondsSinceEpoch;
    final seq = _sonioxItemSequence++;
    final rand = Random().nextInt(1 << 20);
    return 'item_${ts}_${seq}_$rand';
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

    final itemId = _currentSonioxItemId!;
    final transcript = _sonioxTokenBuffers[itemId]?.toString() ?? '';

    // Always reset current buffers, even when transcript is empty.
    // If we don't reset, the next utterances will keep appending to the same
    // itemId, causing concatenated text/audio and duplicated IDs.
    _currentSonioxItemId = null;

    if (transcript.trim().isEmpty) {
      _logger.w('Finalization complete but transcript is empty for $itemId');
      _sonioxTokenBuffers.remove(itemId);
      _sonioxAudioBuffers.remove(itemId);
      return;
    }

    _logger.i('Soniox finalization complete for $itemId: $transcript');

    List<int>? audioBytes = _sonioxAudioBuffers[itemId];

    List<int>? mp3AudioBytes;
    if (audioBytes != null) {
      try {
        final mp3Data = await _audioEncoder.encodePcmToMp3(
          pcmData: Uint8List.fromList(audioBytes),
          sampleRate: 24000,
          numChannels: 1,
        );
        mp3AudioBytes = mp3Data.toList();
        _logger.i(
            'Converted Soniox audio to MP3 (${audioBytes.length} PCM bytes -> ${mp3AudioBytes.length} MP3 bytes)');
      } catch (e) {
        _logger.e('Failed to convert Soniox audio to MP3: $e');
        mp3AudioBytes = audioBytes;
      }
    }

    // Store pending data; we'll emit `onTranscriptionEnd` only after OpenAI
    // confirms the item (so we can attach the proper previousItemId).
    _pendingSonioxFinalizations[itemId] = (
      transcript: transcript,
      audioBytes: mp3AudioBytes,
    );

    // Fallback: if OpenAI doesn't send added/done quickly, emit anyway to avoid
    // missing user bubbles. (We keep previousItemId nullable.)
    _pendingSonioxFinalizationTimers[itemId]?.cancel();
    _pendingSonioxFinalizationTimers[itemId] =
        Timer(_pendingSonioxFinalizationTimeout, () {
      final pending = _pendingSonioxFinalizations.remove(itemId);
      if (pending == null) return;
      _logger.w(
        'OpenAI did not confirm Soniox item $itemId within '
        '${_pendingSonioxFinalizationTimeout.inMilliseconds}ms; emitting transcriptionEnd without previousItemId',
      );
      onTranscriptionEndController.add(TranscriptionEnd(
        id: itemId,
        content: pending.transcript,
        role: Role.user,
        contentIndex: 0,
        previousItemId: itemIdWithPreviousItemId[itemId],
        audioBytes: pending.audioBytes,
      ));
    });

    _sonioxTranscriptions[itemId] = {
      'text': transcript,
      'isFinal': true,
    };

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

    // Free buffers for this item now that we produced the final payload.
    _sonioxTokenBuffers.remove(itemId);
    _sonioxAudioBuffers.remove(itemId);
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

  void _cancelSonioxEndpointTimer() {
    if (_sonioxEndpointTimer != null && _sonioxEndpointTimer!.isActive) {
      _logger.d('Cancelling endpoint timer (user still speaking)');
      _sonioxEndpointTimer?.cancel();
      _sonioxEndpointTimer = null;
    }
  }
}
