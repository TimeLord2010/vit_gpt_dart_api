enum GptModel {
  gpt5,
  gpt41,
  gpt41Mini,
  gpt41Nano,
  o3,
  o4Mini,
  o1Mini,
  o1Preview,
  gpt4oMini,
  gpt4Turbo,
  gpt4o;

  factory GptModel.fromString(String value) {
    return switch (value.toLowerCase().trim()) {
      'gpt-5' => GptModel.gpt5,
      'gpt-4.1' => GptModel.gpt41,
      'gpt-4.1-mini' => GptModel.gpt41Mini,
      'gpt-4.1-nano' => GptModel.gpt41Nano,
      'o3' => GptModel.o3,
      'o4-mini' => GptModel.o4Mini,
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
      GptModel.gpt5 => 'gpt-5',
      GptModel.gpt41 => 'gpt-4.1',
      GptModel.gpt41Mini => 'gpt-4.1-mini',
      GptModel.gpt41Nano => 'gpt-4.1-nano',
      GptModel.o3 => 'o3',
      GptModel.o4Mini => 'o4-mini',
      GptModel.gpt4o => 'gpt-4o',
      GptModel.gpt4oMini => 'gpt-4o-mini',
      GptModel.gpt4Turbo => 'gpt-4-turbo',
      GptModel.o1Mini => 'o1-mini',
      GptModel.o1Preview => 'o1-preview',
    };
  }
}
