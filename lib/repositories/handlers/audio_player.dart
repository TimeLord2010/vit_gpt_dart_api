import 'dart:async';

import 'package:vit_gpt_dart_api/data/configuration.dart';

import '../../data/enums/player_state.dart';
import '../../data/interfaces/simple_audio_player_model.dart';

abstract class AudioPlayer {
  final String audioPath;

  AudioPlayer({
    required this.audioPath,
  });

  bool isPlaying = false;
  double secondsPlayed = 0;

  SimpleAudioPlayer? _currentPlayer;

  void dispose() {
    VitGptConfiguration.logger.d('(AudioPlayer) Disposing');
    _currentPlayer?.dispose();
    _currentPlayer = null;
  }

  void updateUI();

  SimpleAudioPlayer createPlayer(String name, String extension);

  SimpleAudioPlayer getPlayer() {
    var parts = audioPath.split('.');
    var extension = parts.last;

    var player = createPlayer(audioPath, extension);
    return player;
  }

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
      VitGptConfiguration.logger.i('Preparing to play $audioPath');

      var player = getPlayer();
      _currentPlayer = player;

      // Registering for audio progress updates
      Timer.periodic(const Duration(milliseconds: 200), (t) {
        var state = player.state;
        if (state != PlayerState.playing) {
          VitGptConfiguration.logger.d('Flaging audio as finished');
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
      player.play();
      VitGptConfiguration.logger.d('Finished playing');

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
