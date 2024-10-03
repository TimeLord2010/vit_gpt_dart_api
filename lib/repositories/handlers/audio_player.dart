import 'dart:async';
import 'dart:io';

import '../../data/enums/player_state.dart';
import '../../factories/logger.dart';

abstract class AudioPlayer {
  final File audioFile;

  AudioPlayer({
    required this.audioFile,
  });

  bool isPlaying = false;
  double secondsPlayed = 0;

  SimpleAudioPlayer? _currentPlayer;

  void dispose() {
    logger.debug('(AudioPlayer) Disposing');
    _currentPlayer?.dispose();
    _currentPlayer = null;
  }

  void updateUI();

  SimpleAudioPlayer createPlayer(String name, String extension);

  Future<void> play() async {
    // Checking if the file is not already playing
    if (isPlaying) {
      return;
    }

    // Updating playing state
    isPlaying = true;
    updateUI();

    try {
      var completer = Completer<void>();

      // Getting file extension
      var name = audioFile.path;
      logger.info('Preparing to play $name');
      var parts = name.split('.');
      var extension = parts.last;

      var player = createPlayer(name, extension);
      _currentPlayer = player;

      // Registering for audio progress updates
      Timer.periodic(const Duration(milliseconds: 200), (t) {
        var state = player.state;
        if (state != PlayerState.playing) {
          logger.debug('Flaging audio as finished');
          isPlaying = false;
          completer.complete();
          secondsPlayed = 0;
          t.cancel();
          updateUI();
          return;
        }
        // logger.info('Audio progress ($state): ${player.currentPosition}');
        secondsPlayed = player.positionInSeconds;
        updateUI();
      });

      // Play
      try {
        player.play();
        logger.debug('Finished playing');
      } finally {
        dispose();
      }
      return completer.future;
    } finally {
      updateUI();
    }
  }

  void stop() {
    _currentPlayer?.pause();
    _currentPlayer?.dispose();
    _currentPlayer = null;
  }
}

abstract class SimpleAudioPlayer {
  PlayerState get state;

  double get positionInSeconds;

  Future<void> dispose();

  Future<void> pause();

  Future<void> play();
}
