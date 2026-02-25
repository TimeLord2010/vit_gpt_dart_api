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

class OpenaiRealtimeRepository extends BaseRealtimeRepository {
  String sonioxTemporaryKey;

  final _logger = createGptDartLogger('OpenAiRealtimeRepository');

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

  // MARK: Variables

  WebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  final _sentInitialMessages = <String>{};

  final _aiTextResponseBuffer = StringBuffer();

  final Map<String, String> itemIdWithPreviousItemId = {};

  Timer? _initialMessagesTimeoutTimer;

  bool shouldCreateResponseAfterUserSpeechCommit = false;

  // Soniox realtime WebSocket
  WebSocketChannel? _sonioxSocket;

  // Soniox transcription tracking
  // Map structure: item_id -> {text, isFinal}
  final Map<String, Map<String, dynamic>> _sonioxTranscriptions = {};

  // Buffer for collecting Soniox tokens
  final Map<String, StringBuffer> _sonioxTokenBuffers = {};

  // Soniox keepalive timer
  Timer? _sonioxKeepaliveTimer;
  static const Duration _sonioxKeepaliveInterval = Duration(seconds: 10);

  // Soniox endpoint detection timer (for auto-commit after silence)
  Timer? _sonioxEndpointTimer;
  Duration _sonioxEndpointDelay = Duration(milliseconds: 500);

  OpenaiRealtimeRepository({
    required this.sonioxTemporaryKey,
  });

  // MARK: METHODS

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
      // Send manual finalization to Soniox if enabled
      if (sonioxTemporaryKey.isNotEmpty && _sonioxSocket != null) {
        // Send finalize message to Soniox
        final finalizeMessage = jsonEncode({"type": "finalize"});
        _sonioxSocket?.sink.add(finalizeMessage);
        _logger.i('Sent manual finalization to Soniox');
      }
    } else {
      // Use OpenAI's native input_audio_buffer.commit
      sendMessage({
        "type": "input_audio_buffer.commit",
      });
    }
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    if (useSoniox) {
      // Stream audio to Soniox realtime WebSocket if enabled
      if (sonioxTemporaryKey.isNotEmpty && _sonioxSocket != null) {
        _sonioxSocket?.sink.add(audioData);
      }
    } else {
      // Use OpenAI's native input_audio_buffer.append
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

    // Close Soniox WebSocket and timers
    _sonioxKeepaliveTimer?.cancel();
    _sonioxKeepaliveTimer = null;
    _sonioxEndpointTimer?.cancel();
    _sonioxEndpointTimer = null;
    _sonioxSocket?.sink.close();
    _sonioxSocket = null;

    super.close();
    _sentInitialMessages.clear();
    _sonioxTranscriptions.clear();
    _sonioxTokenBuffers.clear();
  }

  @override
  Future<void> open() async {
    socket?.sink.close();
    String? token;

    /// Trying to get session token, in case of a private server.
    final sessionResponse = await getSessionToken();

    token = sessionResponse?.token;
    // Falling back to using API Token
    token ??= await getApiToken();

    // A token is required to open the connection
    if (token == null) {
      onErrorController.add(Exception('No token found'));
      return;
    }

    useSoniox = sessionResponse?.useSoniox ?? false;
    isPressToTalk = sessionResponse?.pressToTalk ?? false;

    // Set Soniox endpoint delay based on td_silence_duration if provided
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

    // Open Soniox realtime WebSocket if enabled
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
      // MARK: System events
      'error': () async {
        Map<String, dynamic> error = data['error'];
        String message = error['message'];
        onErrorController.add(Exception(message));
      },
      'session.created': () async {
        _logger.i('Session created');
        sessionConfig = data['session'];

        try {
          /// Sending initial messages
          List<Message> initialMsgs = sendableInitialMessages.toList();
          _logger.i(
              'Sendable initial messages: ${initialMsgs.map((x) => x.text).join(', ')}');
          if (initialMsgs.isEmpty) return;

          setIsSendingInitialMessages(true);

          // Start timeout timer for initial messages
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

            /// The operation will fail if we try to set "previous_item_id" to
            /// an id not found in the conversation object. To avoid that, lets
            /// wait for a set amount of time.
            if (someHaveId) await Future.delayed(Duration(milliseconds: 100));
          }

          // We are waiting to make sure the OpenAI server has received the
          // last message before creating a response.
          await Future.delayed(Duration(milliseconds: 200));

          /// We need to send the command "response.create" in order to the
          /// assistant recognize the messages.
          ///
          ///
          final previewConfig = {
            "type": "response.create",
            "response": {
              "modalities": ["text", "audio"]
            },
          };

          final stableConfig = {
            "type": "response.create",
            "response": {
              "output_modalities": [
                "audio"
              ] //audio automaticamente contém texto
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
          // This is a Soniox-created item, handle accordingly
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
          }
        } else {
          _confirmInitialMessage(data);
          onConversationItemCreatedController.add(data);
        }
      },
      'conversation.item.added': () async {
        if (data['previous_item_id'] != null) {
          itemIdWithPreviousItemId[data['item']['id']] =
              data['previous_item_id'];
        }
      },

      'conversation.item.done': () async {
        if (data['previous_item_id'] != null) {
          itemIdWithPreviousItemId[data['item']['id']] =
              data['previous_item_id'];
        }

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
          }
        } else {
          _confirmInitialMessage(data);
          onConversationItemCreatedController.add(data);
        }
      },

      // MARK: User events
      'input_audio_buffer.speech_started': () async {
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

        // Only trigger response.create here if NOT using Soniox
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
        }
      },
      'conversation.item.input_audio_transcription.completed': () async {
        String itemId = data['item_id'];
        String content = data['transcript'];

        var transcriptionEnd = TranscriptionEnd(
          id: itemId,
          content: content,
          role: Role.user,
          contentIndex: (data['content_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[itemId],
        );
        onTranscriptionEndController.add(transcriptionEnd);
      },

      // MARK: AI events
      'response.audio.delta': () async {
        // Updating ai speaking status
        if (!isAiSpeaking) {
          onSpeechStartController.add(SpeechStart(
            id: data['response_id'],
            role: Role.assistant,
          ));
        }
        isAiSpeaking = true;

        // Getting and sending audio data
        String base64Data = data['delta'];

        onSpeechController.add(SpeechItem<String>(
          id: data['response_id'],
          audioData: base64Data,
          role: Role.assistant,
          contentIndex: data['content_index'],
        ));
      },
      'response.output_audio.delta': () async {
        // Updating ai speaking status
        if (!isAiSpeaking) {
          onSpeechStartController.add(SpeechStart(
            id: data['response_id'],
            role: Role.assistant,
          ));
        }
        isAiSpeaking = true;

        // Getting and sending audio data
        String base64Data = data['delta'];

        onSpeechController.add(SpeechItem<String>(
          id: data['response_id'],
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
        onTranscriptionEndController.add(TranscriptionEnd(
          id: data['item_id'],
          role: Role.assistant,
          content: _aiTextResponseBuffer.toString(),
          contentIndex: (data['content_index'] as num).toInt(),
          outputIndex: (data['output_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[data['item_id']],
        ));
        _aiTextResponseBuffer.clear();
      },
      'response.output_audio_transcript.done': () async {
        while (itemIdWithPreviousItemId[data['item_id']] == null) {
          await Future.delayed(Duration(seconds: 1));
        }

        onTranscriptionEndController.add(TranscriptionEnd(
          id: data['item_id'],
          role: Role.assistant,
          content: _aiTextResponseBuffer.toString(),
          contentIndex: (data['content_index'] as num).toInt(),
          outputIndex: (data['output_index'] as num).toInt(),
          previousItemId: itemIdWithPreviousItemId[data['item_id']],
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
        // Sent when [stopAiSpeech] is called.

        isAiSpeaking = false;
        onSpeechEndController.add(SpeechEnd(
          id: data['response_id'],
          role: Role.assistant,
          done: false,
        ));
      },
      'response.done': () async {
        var map = data['response'];
        var output = map['output'] as List?;
        if (output != null && output.isNotEmpty) {
          map['previousItemId'] = itemIdWithPreviousItemId[output[0]['id']];
        }
        var response = RealtimeResponse.fromMap(map);
        onResponseController.add(response);
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

  /// Can be overriden to implement server call to generate session token.
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

  /// Checks if the item created was a message, and it so, check if it was a
  /// initial message  to confirm it was received by the server.
  void _confirmInitialMessage(Map<String, dynamic> data) {
    var initialMessages = this.initialMessages ?? [];
    if (initialMessages.isEmpty) {
      return;
    }

    // Checking if the item created was a message
    Map<String, dynamic> item = data['item'];
    dynamic type = item['type'];
    if (type is String && type != 'message') {
      return;
    }

    // Getting the message content that is a text
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

    // Fetches the initialMessage based on text and role
    Role role = Role.fromValue(item['role']);
    var foundInitialMessage = initialMessages.firstWhereOrNull((x) {
      return x.role == role && x.text == text;
    });
    if (foundInitialMessage == null) {
      return;
    }

    // Mark message as sent by creating a unique identifier
    //
    // OpenAI recognizes our message ids, but unfortunely, it converts them to
    // new ones when it creates the conversation items. Forcing us to check the
    // message identity by combining the message role + text.
    String messageKey = _messageKey(role, text);
    _sentInitialMessages.add(messageKey);
    _logger.d('Confirmed message has been sent: $messageKey');

    // Check if all initial messages have been sent
    // Only consider non-empty messages (same filter as in session.created)
    List<Message> nonEmptyInitialMessages = initialMessages.where((msg) {
      return msg.text.trim().isNotEmpty;
    }).toList();

    bool allMessagesSent = nonEmptyInitialMessages.every((msg) {
      String msgKey = '${msg.role.name}:${msg.text}';
      return _sentInitialMessages.contains(msgKey);
    });

    // Notifies the connection was successfull
    if (allMessagesSent) {
      _initialMessagesTimeoutTimer?.cancel();
      _initialMessagesTimeoutTimer = null;
      setIsSendingInitialMessages(false);
    }
  }

  String _messageKey(Role role, String text) {
    return '${role.name}:$text';
  }

  // MARK: Soniox Realtime Integration Methods

  /// Opens Soniox realtime WebSocket connection
  Future<void> _openSonioxRealtimeConnection() async {
    try {
      final sonioxUrl =
          Uri.parse('wss://stt-rt.soniox.com/transcribe-websocket');

      _logger.i('Connecting to Soniox realtime...');
      _sonioxSocket = WebSocketChannel.connect(sonioxUrl);

      // Send initial configuration
      final config = {
        'api_key': sonioxTemporaryKey,
        'model': 'stt-rt-v4',
        'audio_format': 'pcm_s16le',
        'sample_rate': 24000,
        'num_channels': 1,
        "language_hints": ["pt"],
        'enable_speaker_diarization': false,
        'enable_language_identification': false,
        // Enable endpoint detection when not in press-to-talk mode
        if (!isPressToTalk) 'enable_endpoint_detection': true,
        if (!isPressToTalk)
          'max_endpoint_delay_ms': _sonioxEndpointDelay.inMilliseconds,
      };

      _sonioxSocket?.sink.add(jsonEncode(config));
      _logger.i('Sent Soniox configuration');

      // Start keepalive timer
      _startSonioxKeepalive();

      // Listen to Soniox responses
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

  /// Processes incoming messages from Soniox realtime WebSocket
  void _processSonioxRealtimeMessage(dynamic event) {
    try {
      final data = jsonDecode(event) as Map<String, dynamic>;

      // Check for errors
      if (data['error_code'] != null) {
        _logger.e(
            'Soniox error: ${data['error_code']} - ${data['error_message']}');
        return;
      }

      // Process tokens
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
            _currentSonioxItemId ??= _generateItemId();
            _sonioxTokenBuffers.putIfAbsent(
                _currentSonioxItemId!, () => StringBuffer());
            _sonioxTokenBuffers[_currentSonioxItemId!]!.write(text);
          } else {
            _cancelSonioxEndpointTimer();
          }
        }
      }

      // Log progress
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
    return 'item_${Random().nextInt(10000000)}';
  }

  /// Starts keepalive timer to prevent connection timeout during long pauses
  void _startSonioxKeepalive() {
    _sonioxKeepaliveTimer?.cancel();
    _sonioxKeepaliveTimer = Timer.periodic(_sonioxKeepaliveInterval, (timer) {
      if (_sonioxSocket != null) {
        // Send keepalive message (empty JSON object or ping message)
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

  /// Handles Soniox finalization completion
  void _handleSonioxFinalization() {
    if (_currentSonioxItemId == null) {
      _logger.w('Received finalization marker but no current item ID');
      return;
    }

    final itemId = _currentSonioxItemId!;
    final transcript = _sonioxTokenBuffers[itemId]?.toString() ?? '';

    if (transcript.isEmpty) {
      _logger.w('Finalization complete but transcript is empty for $itemId');
      return;
    }

    _logger.i('Soniox finalization complete for $itemId: $transcript');

    // Store the transcription
    _sonioxTranscriptions[itemId] = {
      'text': transcript,
      'isFinal': true,
    };

    // Create conversation item with the transcript
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

    // Call TranscriptionEnd to notify listeners (similar to OpenAI transcription handling)
    var transcriptionEnd = TranscriptionEnd(
      id: itemId,
      content: transcript,
      role: Role.user,
      contentIndex: 0,
      previousItemId: itemIdWithPreviousItemId[itemId],
    );
    onTranscriptionEndController.add(transcriptionEnd);

    // Reset for next utterance
    _currentSonioxItemId = null;
  }

  /// Handles endpoint detection from Soniox
  /// When the <end> token is received and press-to-talk is disabled,
  /// start a timer to automatically commit user audio after silence period
  void _handleSonioxEndpointDetection() {
    _logger.i('Soniox endpoint detected');

    // Only auto-commit if press-to-talk is disabled
    if (!isPressToTalk) {
      _logger.i(
          'Starting endpoint timer (${_sonioxEndpointDelay.inSeconds}s) for auto-commit');

      // Cancel any existing timer
      _cancelSonioxEndpointTimer();

      // Start new timer to commit user audio after the delay
      _sonioxEndpointTimer = Timer(_sonioxEndpointDelay, () {
        _logger.i('Endpoint timer completed, committing user audio');
        commitUserAudio();
      });
    }
  }

  /// Cancels the Soniox endpoint detection timer
  void _cancelSonioxEndpointTimer() {
    if (_sonioxEndpointTimer != null && _sonioxEndpointTimer!.isActive) {
      _logger.d('Cancelling endpoint timer (user still speaking)');
      _sonioxEndpointTimer?.cancel();
      _sonioxEndpointTimer = null;
    }
  }
}
