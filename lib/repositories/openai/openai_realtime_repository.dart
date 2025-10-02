import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vit_dart_extensions/vit_dart_extensions.dart';
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
import 'package:vit_gpt_dart_api/usecases/index.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class OpenaiRealtimeRepository extends BaseRealtimeRepository {
  final _logger = createGptDartLogger('OpenAiRealtimeRepository');

  static const Duration initialMessagesTimeout = Duration(seconds: 5);

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

  // MARK: Variables

  WebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  final _sentInitialMessages = <String>{};

  final _aiTextResponseBuffer = StringBuffer();

  Timer? _initialMessagesTimeoutTimer;

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
    _initialMessagesTimeoutTimer?.cancel();
    _initialMessagesTimeoutTimer = null;
    socket?.sink.close();
    socket = null;

    super.close();
    _sentInitialMessages.clear();
  }

  @override
  Future<void> open() async {
    socket?.sink.close();
    String? token;

    /// Trying to get session token, in case of a private server.
    token = await getSessionToken();

    // Falling back to using API Token
    token ??= await getApiToken();

    // A token is required to open the connection
    if (token == null) {
      onErrorController.add(Exception('No token found'));
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
        onSocketDataController.add(data);
        String type = data['type'];
        await _processServerMessage(type, data);
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
  }

  Future<void> _processServerMessage(
    String type,
    Map<String, dynamic> data,
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
                    'type': role == Role.assistant ? 'text' : 'input_text',
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
          sendMessage({
            "type": "response.create",
            "response": {
              "modalities": ["text", "audio"]
            },
          });
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
        _confirmInitialMessage(data);
        onConversationItemCreatedController.add(data);
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
        onSpeechEndController.add(SpeechEnd(
          id: data['item_id'],
          role: Role.user,
          done: true,
        ));
        isUserSpeaking = false;
      },
      'conversation.item.input_audio_transcription.completed': () async {
        var transcriptionEnd = TranscriptionEnd(
          id: data['item_id'],
          content: data['transcript'],
          role: Role.user,
          contentIndex: (data['content_index'] as num).toInt(),
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
      'response.audio.done': () async {
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
          id: data['response_id'],
          role: Role.assistant,
          content: _aiTextResponseBuffer.toString(),
          contentIndex: (data['content_index'] as num).toInt(),
          outputIndex: (data['output_index'] as num).toInt(),
        ));
        _aiTextResponseBuffer.clear();
      },
      'response.audio_transcript.delta': () async {
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
  Future<String?> getSessionToken() async => null;

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
}
