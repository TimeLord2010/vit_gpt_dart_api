enum ImageStyle {
  vivid,
  natural;

  @override
  String toString() {
    return switch (this) {
      ImageStyle.vivid => 'vivid',
      ImageStyle.natural => 'natural',
    };
  }
}
