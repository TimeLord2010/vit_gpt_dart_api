import 'dart:io';

abstract class AudioPlayerModel {
  final File file;

  AudioPlayerModel(this.file);

  Future<void> play();

  Future<void> stop();
}
