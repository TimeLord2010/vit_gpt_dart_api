enum ImageModel {
  dalle2,
  dalle3;

  @override
  String toString() {
    return switch (this) {
      ImageModel.dalle2 => 'dall-e-2',
      ImageModel.dalle3 => 'dall-e-3',
    };
  }
}
