class RealtimeSessionConfig {
  final String token;
  final String model;
  final bool pressToTalk;
  final int? tdSilenceDuration;

  const RealtimeSessionConfig({
    required this.token,
    required this.model,
    this.pressToTalk = false,
    this.tdSilenceDuration,
  });
}

class SonioxRealtimeSessionConfig extends RealtimeSessionConfig {
  final bool useSoniox;

  const SonioxRealtimeSessionConfig({
    required super.token,
    required super.model,
    super.pressToTalk = false,
    super.tdSilenceDuration,
    required this.useSoniox,
  });
}
