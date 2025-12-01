enum Role {
  user,
  assistant,
  system;

  bool get isUser => this == user;
  bool get isAssistant => this == assistant;
  bool get isSystem => this == system;

  factory Role.fromValue(String value) {
    return switch (value) {
      'user' => user,
      'assistant' => assistant,
      'ai' => assistant,
      _ => system,
    };
  }
}
