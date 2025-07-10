## 6.0.1

- Feat: `Message` class now has "usage".

## 6.0.0

- BREAKING: `RealtimeModel` no longer has "onUsage" stream, use "onResponse".
- Feat: `RealtimeModel` now has "onResponse" stream, meant to provide the ai response and the usage in on single event.

## 5.2.0

- Feat: `Usage` class present in the "response.done" event of  `OpenaiRealtimeRepository` now has
the cached tokens details.

## 5.1.0

- Feat: `Message` now accepts a more flexible json in the "Message.fromMap" constructor.

## 5.0.1

- Fix: All factories in `DynamicFactory` have a setter and getter.
- Feat: Everytime a method tries to retrive/save something from/to local storage, the code will either abort or return a default value instead of throwing an exception.
- Fix: "completion" from `DynamicFactories` is used in "createCompletionRepository" method.

## 5.0.0

- BREAKING: Method was renamed in `ThreadsModel` from "sendMessage" to "createMessage".
- BREAKING: Class `VitGptConfiguration` was renamed to `VitGptDartConfiguration`.
- BREAKING: Removed function "setupFactories".
- BREAKING: Renamed factories in `DynamicFactories`:
    - simplePlayerFactory → simplePlayer.
    - speeachToText → transcriber.
    - completionFactory → completionWithAssistant.


## 4.2.0

- Feat: Added "logLevel" in `VitGptConfiguration` to make easier to change the log level across the package.
- Fix: Logs are no longer shown in profile and release mode by default.

## 4.1.0

- Feat: `TranscriptionEnd` now includes "content" which is the accumulated text for the transcription.
- Refac: Uses package "logger" to create logs. To customaze it, change on "VitGptConfiguration.logger".

## 4.0.0

- BREAKING: Refactored `RealtimeModel` and therefore, `OpenaiRealtimeRepository`.
- BREAKING: Refactored `Message` class to be consistent with other APIs.
- BREAKING: `SenderType` enum is now called `Role` to be consistent with other APIs.
- Feat: `RealtimeModel` now has token usage stream.

## 3.10.3

- Fix: `OpenaiRealtimeRepository` fixed typo on event "conversation.item.created".

## 3.10.2

- Fix: `OpenaiRealtimeRepository` correctly catches open ai events for ai text response.

## 3.10.1

- Fix: When using openai realtime, sends the audio data to the stream in the correct order.

## 3.10.0

- Feat: `DynamicFactories` now has public simple player factory setter.

## 3.9.0

- Feat: Cancel ai response in `RealtimeModel`.

## 3.8.0

- Feat: New stream "onRawAiAudio" on `RealtimeModel`.
- Feat: New property "streamAiAudioAsText" on `RealtimeModel`.
- Fix: "isUserSpeaking" is not properly updated on `OpenaiRealtimeRepository`.

## 3.7.0

- Feat: Any error in the server messages in `OpenaiRealtimeRepository` is now handled.
- Fix: Rate limits are now correctly parsed in `OpenaiRealtimeRepository`.

## 3.6.1

- Fix: `OpenaiRealtimeRepository` now correctly handles base 64 data.

## 3.6.0

- Feat: Method "getApiToken" now will try to fetch the api token from the http client if the local storage was not set.
- Fix: `OpenaiRealtimeRepository` now produces the correct headers.

## 3.5.0

- Feat: `RealtimeModel` now has the "isConnected" property.
- Fix: `OpenaiRealtimeRepository` now correctly emits events as String instead of Map.

## 3.4.2

- Fix: `OpenaiRealtimeRepository` is now correctly configured to use WebSocket connection instead of socket io.

## 3.4.1

- Fix: Adjusted web socket headers in `OpenaiRealtimeRepository`.

## 3.4.0

- Feat: `RealtimeModel` now has "getSocketHeaders" to improve customization for websocket.

## 3.3.2

- Fix: send user audio data in `OpenaiRealtimeRepository` no longer sends invalid data.
- Log: Added logs to `OpenaiRealtimeRepository`.

## 3.3.1

- Feat: A `LocalStorageModel` is no longer required to set an open ai token.

## 3.3.0

- Feat: Realtime model, repository and factory.
- Feat: Completion factory in `DynamicFactory`.
- Doc: Added example of completion repository.
- BREAKING: Removed property "threadId" from `Message`.

## 3.2.3

- Feat: updated dependencies

## 3.2.2

- Fix: `Conversation` parse from map.

## 3.2.1

- Fix: `ThreadsModel` dynamic factory propertly works now.

## 3.2.0

- Feat: `ThreadsRepository` now accepts custom dio client on constructor.

## 3.1.1

- Fix: `CompletionRepository` now correctly checks for empty previous messages.

## 3.1.0

- Refac: "message" parameter is not a optional named parameter in `ConversationRepository`.
- Feat: Added optional parameter "previousMessage" to "prompt" method in `ConversationRepository`.

## 3.0.0

- BREAKING: `ConversationRepository` no longer has "onFirstMessageCreated" on "prompt" method.
- Added optional parameter "previousMessages" to `CompletionModel` methods "fetch" and "fetchStream".
- Added the getter "addsResponseAutomatically" to `CompletionModel`.
- Removed constructor parameter "messages" from `CompletionRepository` in favor of "previousMessages" of "fetch" and "fetchStream" methods.
- `AssistantRepository` now uses the API parameter "additional_messages", which eliminates the need to call another route separately to add the message to the thread.
- Added "onMessageCreated" and "onMessageCreateError" callbacks to the "prompt" method  from `ConversationRepository`.
- The "prompt" method from `ConversationRepository` no longer waits for message creations on the thread and instead relies on the new callbacks to improve performance.

## 2.5.2

- Fix: `TranscriberRepository` now correctly closes the stream of strings when the transcription is stopped.

## 2.5.1

- Fix: `AssistantRepository` now correctly uses the http client given in the constructor.

## 2.5.0

- Feat: added "assistantRepository" factory to `DynamicFactories`.

## 2.4.2

- Fix: Stop speaker

## 2.4.1

- Fixed `createTranscriberRepository`.

## 2.4.0

- Renamed `createListenerRepository` to `createTranscriberRepository`.

## 2.3.0

- Added "onMicVolumeChange" and "onSilenceChange" to `TranscriberModel`.

## 2.2.2

- Added security checks on `TranscriberRepository` to prevent errors in case of miss use of methods.

## 2.2.1

- Renamed `ListenerRepository` to `TranscriberRepository`.
- FIX: `TranscriberRepository` now disposes its voice recorder.

## 2.2.0

- Renamed `ListenerModel` to `TranscribeModel`.
- Deprecated "transcribe" method in favor of `TranscribeModel` usage directly.

## 2.1.0

- Feat: Added dynamic factory for `ListenerModel` (used on transcription).

## 2.0.1

- Refac: 'model' is not longer required when creating a instance of `Assistant`.

## 2.0.0

- Feat: Renamed completion onChunk to onJsonComplete to make it more clearer. Also added the same field to `ConversationRepository`.

## 1.8.6

- Feat: onChunk callback for completion models.

## 1.8.5

- FEAT: Dynamic factory for threads model

## 1.8.4

- Fix: made `SpeakerHandler` logger private.

## 1.8.3

- Added logs to `SpeakerHandler`.

## 1.8.2

- Added safe guard to `SpeakerHandler` on "speakSentences" to prevent multiple timers.

## 1.8.1

- Speaker handler no longer processes new chunks if it is stopped.

## 1.8.0

- Volume stream support for Speaker Handler.

## 1.7.0

- Max sentence delay in speaker handler and local storage.

## 1.6.0

- Function for onPlay and onSentenceCompleted on speaker handler.

## 1.5.1

- Fix: parse of json stream from open ai

## 1.5.0

- Ability to catch and handle exception on the assistant repository

## 1.4.0

- Ability to save thread title.

## 1.3.2

- Fixed speaker omitting pontuation on sentences.

## 1.3.1

- Silence detector with custom static variables.

## 1.3.0

- Silence detector on recorder handler.

## 1.2.3

- Ability to change speaker voice.

## 1.2.2

- Fixed bug when loading non existent thread.

## 1.2.1

- Allow custom tts handler.

## 1.2.0

- Assistant list and run.

## 1.1.1

- Configuration options for audio.

## 1.1.0

- Ask assistant on thread.

## 1.0.0

- Initial version.
