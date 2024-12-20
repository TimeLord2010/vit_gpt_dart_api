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
