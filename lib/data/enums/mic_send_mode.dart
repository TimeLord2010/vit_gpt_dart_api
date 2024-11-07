enum MicSendMode {
  manual,
  intensitySilenceDetection;

  factory MicSendMode.fromString(String value) {
    return switch (value) {
      'intensitySilenceDetection' => intensitySilenceDetection,
      _ => manual,
    };
  }

  @override
  String toString() {
    return name;
  }
}
