import 'dart:async';
import 'dart:io';

import 'package:vit_gpt_dart_api/data/interfaces/simple_audio_player_model.dart';
import 'package:vit_gpt_dart_api/usecases/object/string/split_preserving_separator.dart';

import '../../factories/logger.dart';
import '../../usecases/audio/download_tts_file.dart';

/// Handles the stream of text to generate multiple audio files to be played
/// to the user.
class SpeakerHandler {
  final SimpleAudioPlayer Function(File file) playerFactory;
  final String voice;

  SpeakerHandler({
    required this.playerFactory,
    this.voice = 'onyx',
  });

  final List<Future<File>> _sentences = [];

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
    // TODO Dynamic value to configuration
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      if (isSpeaking) {
        return;
      }
      if (_sentences.isEmpty) {
        return;
      }
      if (stopped) {
        player?.stop();
        timer.cancel();
        return;
      }
      isSpeaking = true;
      try {
        var sentence = await _sentences.removeAt(0);
        player = playerFactory(sentence);
        await player!.play();
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
      // fileCount++;
      var audioFile = _generateAudio(sentence);
      _sentences.add(audioFile);
      // files.add(audioFile);
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
}
