import 'dart:async';
import 'dart:io';

import 'package:vit_gpt_dart_api/data/interfaces/simple_audio_player_model.dart';
import 'package:vit_gpt_dart_api/usecases/object/string/split_preserving_separator.dart';

import '../../data/dynamic_factories.dart';
import '../../factories/logger.dart';
import '../../usecases/audio/download_tts_file.dart';

/// SpeakerHandler handles the streaming and conversion of text into audio files.
/// It is responsible for processing text chunks, generating audio for sentences,
/// and managing the playback of these audio files using a specified audio player.
class SpeakerHandler {
  final _volumeController = StreamController<double>();

  final SimpleAudioPlayer Function(File file) playerFactory;

  /// The voice parameter used for text-to-speech conversion.
  final String voice;

  /// Callback executed when a sentence is played. Provides the sentence and its audio file.
  void Function(String sentence, File file)? onPlay;

  /// Maximum delay between processing two consecutive sentences.
  final Duration maxSentenceDelay;

  /// Called whenever a new sentence is recognized.
  ///
  /// If this function returns a string, the sentence recognized is overriden.
  String? Function(String)? onSentenceCompleted;

  SpeakerHandler({
    SimpleAudioPlayer Function(File file)? playerFactory,
    this.onPlay,
    this.onSentenceCompleted,
    String? voice,
    Duration? maxSentenceDelay,
  })  : playerFactory = playerFactory ?? DynamicFactories.simplePlayerFactory,
        maxSentenceDelay =
            maxSentenceDelay ?? const Duration(milliseconds: 250),
        voice = voice ?? 'onyx';

  static Future<SpeakerHandler> fromLocalStorage({
    String? Function(String)? onSentenceCompleted,
    void Function(String sentence, File file)? onPlay,
  }) async {
    var localRep = DynamicFactories.localStorage;
    var maxSentenceDelay = await localRep.getSentenceInterval();
    var voice = await localRep.getSpeakerVoice();
    return SpeakerHandler(
      playerFactory: DynamicFactories.simplePlayerFactory,
      maxSentenceDelay: maxSentenceDelay,
      voice: voice,
      onPlay: onPlay,
      onSentenceCompleted: onSentenceCompleted,
    );
  }

  final List<(String, Future<File>)> _sentences = [];

  /// Accumulator variable to help build a sentence through string chunks.
  String _currentSencence = '';

  Timer? _timer;

  bool isSpeaking = false;

  SimpleAudioPlayer? player;

  bool stopped = false;

  bool get hasPendingSpeaches {
    if (stopped) return false;
    if (isSpeaking) return true;
    return _sentences.isNotEmpty;
  }

  void speakSentences() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (stopped) {
        player?.stop();
        timer.cancel();
        return;
      }
      if (isSpeaking) {
        return;
      }
      if (_sentences.isEmpty) {
        return;
      }
      isSpeaking = true;
      try {
        var (sentence, fileFuture) = _sentences.removeAt(0);
        await Future.delayed(maxSentenceDelay, () async {
          var file = await fileFuture;
          var localPlayer = playerFactory(file);
          player = localPlayer;
          if (onPlay != null) onPlay!(sentence, file);
          var playFuture = localPlayer.play();
          var volumeStream = localPlayer.getVolumeIntensity();
          if (volumeStream != null) {
            await for (var volume in volumeStream) {
              _volumeController.add(volume);
            }
          }
          await playFuture;
        });
      } finally {
        isSpeaking = false;
      }
    });
  }

  void dispose() {
    stopped = true;
    _timer?.cancel();
  }

  Future<void> process(String chunk) async {
    // We generate one file for each sentence. So, we need to split the string
    // using the sentence separator characters.
    _currentSencence += chunk;

    Pattern separator = RegExp(r'\.|\?|!');

    if (!_currentSencence.contains(separator)) {
      // The current sentence is not completed. No more actions are needed at
      // this time.
      return;
    }

    // Handling sentence end and begin to process new sentence

    Iterable<String> parts =
        splitPreservingSeparator(_currentSencence, separator);

    // Filtering empty parts for cases like "...".
    parts = parts.map((x) => x.trim()).where((part) => part.trim().isNotEmpty);

    if (parts.isEmpty) {
      _currentSencence = '';
      return;
    }

    // Means that the sentence is completed. So we need to create a audio
    // file.
    var sentence = parts.first;

    // We need to begin the processing of the next sentences.
    var rest = parts.skip(1).join('.');
    _currentSencence = '';

    if (sentence.isNotEmpty) {
      logger.debug('Completed reading a sentence: $sentence');
      if (onSentenceCompleted != null) {
        var newSentence = onSentenceCompleted!(sentence);
        if (newSentence != null) {
          sentence = newSentence;
        }
      }
      var audioFile = _generateAudio(sentence);
      _sentences.add((sentence, audioFile));
    }

    await process(rest);
  }

  Future<File> _generateAudio(String sentence) async {
    var file = await downloadTTSfile(
      voice: voice,
      input: sentence,
    );
    return file;
  }

  Stream<double> getVolumeStream() => _volumeController.stream;
}
