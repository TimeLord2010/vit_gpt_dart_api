enum AudioModel {
  whisper1;

  @override
  String toString() {
    return switch (this) {
      AudioModel.whisper1 => 'whisper-1',
    };
  }
}
