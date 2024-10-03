import 'dart:typed_data';

import '../enums/image_model.dart';
import '../enums/image_size.dart';
import '../enums/image_style.dart';

abstract class ImageGenerationModel {
  /// Generates a image using a prompt.
  ///
  /// Dalle-e-2 only parameters:
  /// - [size] with dimensions: 256x256 or 512x512
  ///
  /// Dall-e-3 only parameters:
  /// - [highQuality] = true
  /// - [size] with dimensions: 1792x1024 or 1024x1792
  /// - [style] = 'Natural'
  Future<Uint8List> generate({
    required String prompt,
    ImageModel? model,
    bool? highQuality,
    ImageStyle? style,
    ImageSize? size,
    void Function(double progress)? onDownloadProgress,
  });
}
