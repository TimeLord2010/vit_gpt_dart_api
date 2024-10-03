import 'dart:async';
import 'dart:io';

import 'package:chatgpt_chat/data/enums/audio_format.dart';
import 'package:flutter/widgets.dart';
import 'package:ogg_opus_player/ogg_opus_player.dart';

import '../../factories/logger.dart';

class AudioPlayer extends ChangeNotifier {
  final File audioFile;

  AudioPlayer({
    required this.audioFile,
  });

  bool isPlaying = false;
  double secondsPlayed = 0;

  OggOpusPlayer? _oggPlayer;

  @override
  void dispose() {
    _oggPlayer?.dispose();
    super.dispose();
  }

  Future<void> play() async {
    // Checking if the file is not already playing
    if (isPlaying) {
      return;
    }

    // Updating playing state
    isPlaying = true;
    notifyListeners();

    try {
      var completer = Completer<void>();

      // Getting file extension
      var name = audioFile.path;
      logger.info('Preparing to play $name');
      var parts = name.split('.');
      var extension = parts.last;

      if (extension == AudioFormat.opus.name) {
        var player = OggOpusPlayer(name);
        _oggPlayer = player;

        // Registering for audio progress updates
        Timer.periodic(const Duration(milliseconds: 200), (t) {
          var state = player.state.value;
          if (state != PlayerState.playing) {
            logger.debug('Flaging audio is finished');
            isPlaying = false;
            completer.complete();
            secondsPlayed = 0;
            t.cancel();
            notifyListeners();
            return;
          }
          // logger.info('Audio progress ($state): ${player.currentPosition}');
          secondsPlayed = player.currentPosition;
          notifyListeners();
        });

        // Play
        unawaited(Future.sync(
          () {
            try {
              player.play();
              logger.debug('Finished playing');
            } finally {
              logger.debug('Disposing player');
              player.dispose();
              _oggPlayer = null;
            }
          },
        ));
        return completer.future;
      } else {
        logger.error('Unsupported audio format to play: $extension');
      }
    } finally {
      notifyListeners();
    }
  }

  void stop() {
    _oggPlayer?.pause();
    _oggPlayer?.dispose();
  }
}
