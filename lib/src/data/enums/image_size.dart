enum ImageSize {
  square256, // Dall-e-2
  square512, // Dall-e-2
  square1024, // Dall-e-2 and Dall-e-3
  rect1792x1024, // Dall-e-3
  rect1024x1792; // Dall-e-3

  @override
  String toString() {
    return switch (this) {
      ImageSize.square256 => '256x256',
      ImageSize.square512 => '512x512',
      ImageSize.square1024 => '1024x1024',
      ImageSize.rect1024x1792 => '1024x1792',
      ImageSize.rect1792x1024 => '1792x1024',
    };
  }
}
