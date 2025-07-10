enum Role {
  user,
  assistant,
  system;

  factory Role.fromValue(String value) {
    return switch (value) {
      'user' => user,
      'assistant' => assistant,
      'ai' => assistant,
      _ => system,
    };
  }
}
