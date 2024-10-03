enum GptModel {
  o1Mini,
  o1Preview,
  gpt4oMini,
  gpt4Turbo,
  gpt4o;

  factory GptModel.fromString(String value) {
    return switch (value) {
      'o1-mini' => GptModel.o1Mini,
      'o1-preview' => GptModel.o1Preview,
      'gpt-4o' => GptModel.gpt4o,
      'gpt-4-turbo' => GptModel.gpt4Turbo,
      _ => GptModel.gpt4oMini,
    };
  }

  @override
  String toString() {
    return switch (this) {
      GptModel.gpt4o => 'gpt-4o',
      GptModel.gpt4oMini => 'gpt-4o-mini',
      GptModel.gpt4Turbo => 'gpt-4-turbo',
      GptModel.o1Mini => 'o1-mini',
      GptModel.o1Preview => 'o1-preview',
    };
  }
}
