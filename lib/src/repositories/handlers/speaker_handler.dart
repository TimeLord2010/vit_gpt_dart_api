import 'dart:async';
import 'dart:io';

import 'package:chatgpt_chat/factories/logger.dart';
import 'package:chatgpt_chat/repositories/handlers/audio_player.dart';
import 'package:chatgpt_chat/usecases/audio/download_tts_file.dart';

/// Handles the stream of text to generate multiple audio files to be played
/// to the user.
class SpeakerHandler {
  // int fileCount = 0;
  // final files = StreamController<File>();
  String voice = 'onyx'; // TODO: Dynamic voice

  final List<Future<File>> _sentences = [];
  String _currentSencence = '';

  Timer? _timer;

  bool isSpeaking = false;

  AudioPlayer? player;

  bool stopped = false;

  bool get hasPendingSpeaches {
    if (stopped) return false;
    if (isSpeaking) return true;
    return _sentences.isNotEmpty;
  }

  void speakSentences() {
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
        player = AudioPlayer(audioFile: sentence);
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
    // using the dot character.
    _currentSencence += chunk;

    Pattern separator = RegExp(r'\.|\?|!');

    if (!_currentSencence.contains(separator)) {
      return;
    }

    Iterable<String> parts = _currentSencence.split(separator);

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
