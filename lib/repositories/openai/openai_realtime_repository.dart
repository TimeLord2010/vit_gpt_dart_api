import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
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
import 'package:vit_gpt_dart_api/usecases/index.dart';

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

  // MARK: Variables

  WebSocketChannel? socket;

  Map<String, dynamic>? sessionConfig;

  final _sentInitialMessages = <String>{};

  final _aiTextResponseBuffer = StringBuffer();

  final Map<String, String> itemIdWithPreviousItemId = {};

  Timer? _initialMessagesTimeoutTimer;

  bool shouldCreateResponseAfterUserSpeechCommit = false;

  // Audio buffering for Soniox transcription
  final List<Uint8List> _audioAccumulationBuffer = [];
  Uint8List? _committedAudioBuffer;

  // Soniox transcription tracking
  // Map structure: item_id -> {bytes, fileId, transcriptionId, text}
  final Map<String, Map<String, dynamic>> _sonioxTranscriptions = {};

  // Dio client for Soniox API
  late final Dio _sonioxClient = Dio(BaseOptions(
    baseUrl: 'https://api.soniox.com/v1',
  ));

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
  void commitUserAudio() {
    shouldCreateResponseAfterUserSpeechCommit = true;

    // Transfer accumulated audio to committed buffer (only if Soniox is enabled)
    if (sonioxTemporaryKey.isNotEmpty && _audioAccumulationBuffer.isNotEmpty) {
      // Combine all accumulated chunks into a single buffer
      int totalLength =
          _audioAccumulationBuffer.fold(0, (sum, chunk) => sum + chunk.length);
      final combined = Uint8List(totalLength);
      int offset = 0;
      for (var chunk in _audioAccumulationBuffer) {
        combined.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      _committedAudioBuffer = combined;

      // Clear accumulation buffer
      _audioAccumulationBuffer.clear();
    }

    sendMessage({
      "type": "input_audio_buffer.commit",
    });
  }

  @override
  void sendUserAudio(Uint8List audioData) {
    sonioxTemporaryKey =
        '4de247e73bfcaa8e061c240f17f4cffcea3e585d2fe969ab55dbd160f54e77e9';
    // Accumulate audio data (only if Soniox is enabled)
    if (sonioxTemporaryKey.isNotEmpty) {
      _audioAccumulationBuffer.add(Uint8List.fromList(audioData));
    }

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
    final sessionResponse = await getSessionToken();

    token = sessionResponse?.token;
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
        );

    final protocols = [
      "realtime",
      "openai-insecure-api-key.$token",
    ];

    final bool isPreview = sessionResponse?.model.contains('preview') ?? true;

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
        _confirmInitialMessage(data);
        onConversationItemCreatedController.add(data);
      },
      'conversation.item.done': () async {
        _confirmInitialMessage(data);
        if (data['previous_item_id'] != null) {
          itemIdWithPreviousItemId[data['item']['id']] =
              data['previous_item_id'];
        }
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
        String itemId = data['item_id'];

        onSpeechEndController.add(SpeechEnd(
          id: itemId,
          role: Role.user,
          done: true,
        ));
        isUserSpeaking = false;

        // Process audio for Soniox transcription (only if Soniox is enabled)
        print(
            'sonioxTemporaryKey.isNotEmpty: ${sonioxTemporaryKey.isNotEmpty}, _committedAudioBuffer != null: ${_committedAudioBuffer != null}');
        if (sonioxTemporaryKey.isNotEmpty && _committedAudioBuffer != null) {
          _processSonioxTranscription(itemId, _committedAudioBuffer!);
          _committedAudioBuffer = null;
        }

        if (shouldCreateResponseAfterUserSpeechCommit) {
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
            },
          };

          sendMessage(isPreview ? previewConfig : stableConfig);
        }
      },
      'conversation.item.input_audio_transcription.completed': () async {
        String itemId = data['item_id'];
        String content = data['transcript'];

        // Try to append Soniox transcription
        content = await _appendSonioxTranscription(itemId, content);

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
  Future<({String token, String model})?> getSessionToken() async => null;

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

  // MARK: Soniox Integration Methods

  /// Converts PCM audio to WAV format for Soniox upload
  ///
  /// The input is PCM s16le at 24000 Hz mono audio.
  /// WAV format requires a header with audio specifications followed by the PCM data.
  Future<Uint8List> _convertPcmToWav(Uint8List pcmData) async {
    _logger.d('Converting PCM to WAV: ${pcmData.length} bytes');

    const int sampleRate = 24000;
    const int numChannels = 1; // Mono
    const int bitsPerSample = 16; // s16le = 16-bit

    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int dataSize = pcmData.length;
    final int fileSize =
        36 + dataSize; // 44 byte header - 8 bytes for RIFF header

    final ByteData header = ByteData(44);

    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little); // File size - 8

    // WAVE header
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    header.setUint16(22, numChannels, Endian.little); // NumChannels
    header.setUint32(24, sampleRate, Endian.little); // SampleRate
    header.setUint32(28, byteRate, Endian.little); // ByteRate
    header.setUint16(32, blockAlign, Endian.little); // BlockAlign
    header.setUint16(34, bitsPerSample, Endian.little); // BitsPerSample

    // data subchunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little); // Subchunk2Size

    // Combine header and PCM data
    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcmData);

    _logger.d('WAV conversion complete: ${wavData.length} bytes');
    return wavData;
  }

  /// Processes audio for Soniox transcription
  void _processSonioxTranscription(String itemId, Uint8List audioBytes) async {
    try {
      // Convert PCM to WAV format
      final wavBytes = await _convertPcmToWav(audioBytes);

      // Initialize map entry for this item
      _sonioxTranscriptions[itemId] = {
        'bytes': wavBytes,
        'fileId': null,
        'transcriptionId': null,
        'text': null,
      };

      // Upload file to Soniox
      final fileId = await _uploadFileToSoniox(wavBytes, itemId);
      _sonioxTranscriptions[itemId]!['fileId'] = fileId;

      // Create transcription
      final transcriptionId = await _createSonioxTranscription(fileId);
      _sonioxTranscriptions[itemId]!['transcriptionId'] = transcriptionId;

      // Start monitoring transcription status
      _monitorSonioxTranscription(itemId, transcriptionId);
    } catch (e) {
      _logger.e('Error processing Soniox transcription for $itemId: $e');
    }
  }

  /// Uploads audio file to Soniox
  Future<String> _uploadFileToSoniox(
      Uint8List audioBytes, String itemId) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          audioBytes,
          filename: '$itemId.wav',
          contentType: DioMediaType('audio', 'wav'),
        ),
        'client_reference_id': itemId,
      });

      final response = await _sonioxClient.post(
        '/files',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $sonioxTemporaryKey',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error uploading file to Soniox: $e');
      rethrow;
    }
  }

  /// Creates a transcription in Soniox
  Future<String> _createSonioxTranscription(String fileId) async {
    try {
      final requestBody = {
        'model': 'stt-async-v4',
        'file_id': fileId,
      };

      final response = await _sonioxClient.post(
        '/transcriptions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $sonioxTemporaryKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        throw Exception(
            'Failed to create transcription: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error creating Soniox transcription: $e');
      rethrow;
    }
  }

  /// Monitors transcription status and fetches transcript when complete
  void _monitorSonioxTranscription(
      String itemId, String transcriptionId) async {
    try {
      while (true) {
        await Future.delayed(Duration(milliseconds: 1500));

        final status = await _getSonioxTranscriptionStatus(transcriptionId);

        if (status == 'completed') {
          final transcript = await _getSonioxTranscript(transcriptionId);

          if (_sonioxTranscriptions.containsKey(itemId)) {
            _sonioxTranscriptions[itemId]!['text'] = transcript;
            _logger.i('Soniox transcription completed for $itemId');
          }
          break;
        } else if (status == 'error') {
          _logger.e('Soniox transcription failed for $itemId');
          break;
        }
        // Continue polling for 'queued' and 'processing' statuses
      }
    } catch (e) {
      _logger.e('Error monitoring Soniox transcription: $e');
    }
  }

  /// Gets the status of a Soniox transcription
  Future<String> _getSonioxTranscriptionStatus(String transcriptionId) async {
    try {
      final response = await _sonioxClient.get(
        '/transcriptions/$transcriptionId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $sonioxTemporaryKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['status'] as String;
      } else {
        throw Exception(
            'Failed to get transcription status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error getting Soniox transcription status: $e');
      rethrow;
    }
  }

  /// Gets the transcript from a completed Soniox transcription
  Future<String> _getSonioxTranscript(String transcriptionId) async {
    try {
      final response = await _sonioxClient.get(
        '/transcriptions/$transcriptionId/transcript',
        options: Options(
          headers: {
            'Authorization': 'Bearer $sonioxTemporaryKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['text'] as String;
      } else {
        throw Exception('Failed to get transcript: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error getting Soniox transcript: $e');
      rethrow;
    }
  }

  /// Appends Soniox transcription to content with retry logic
  Future<String> _appendSonioxTranscription(
      String itemId, String originalContent) async {
    // Return original content immediately if Soniox is disabled
    if (sonioxTemporaryKey.isEmpty) {
      return originalContent;
    }

    const maxAttempts = 5;
    const retryDelay = Duration(milliseconds: 1500);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (_sonioxTranscriptions.containsKey(itemId)) {
        final transcriptionData = _sonioxTranscriptions[itemId]!;
        final sonioxText = transcriptionData['text'] as String?;

        if (sonioxText != null && sonioxText.isNotEmpty) {
          // Append Soniox transcription with two line breaks
          return '$originalContent\n\n$sonioxText';
        }
      }

      // Wait before retrying (except on last attempt)
      if (attempt < maxAttempts - 1) {
        await Future.delayed(retryDelay);
      }
    }

    // Return original content if Soniox transcription not found after retries
    _logger.w(
        'Soniox transcription not found for $itemId after $maxAttempts attempts');
    return originalContent;
  }
}
