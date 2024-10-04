import '../enums/player_state.dart';

abstract class SimpleAudioPlayer {
  PlayerState get state;

  double get positionInSeconds;

  Future<void> dispose();

  Future<void> pause();

  Future<void> stop();

  Future<void> play();
}
