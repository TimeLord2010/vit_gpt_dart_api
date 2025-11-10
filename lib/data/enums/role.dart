enum Role {
  user,
  assistant,
  undefined,
  system;

  bool get isUser => this == user;
  bool get isAssistant => this == assistant;
  bool get isSystem => this == system;
  bool get isUndefinded => this == undefined;

  factory Role.fromValue(String value) {
    return switch (value) {
      'user' => user,
      'assistant' => assistant,
      'ai' => assistant,
      'undefined' => undefined,
      _ => system,
    };
  }
}
