import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';

import '../data/enums/image_model.dart';
import '../data/enums/image_size.dart';
import '../data/enums/image_style.dart';
import '../data/interfaces/image_generation_model.dart';

class ImageGenerationRepository extends ImageGenerationModel {
  final Dio dio;

  ImageGenerationRepository({
    required this.dio,
  });

  @override
  Future<Uint8List> generate({
    required String prompt,
    ImageModel? model,
    bool? highQuality,
    ImageStyle? style,
    ImageSize? size,
    void Function(double progress)? onDownloadProgress,
  }) async {
    var url = 'https://api.openai.com/v1/images/generations';
    var response = await dio.post(
      url,
      data: {
        'prompt': prompt,
        'model': (model ?? ImageModel.dalle2).toString(),
        'quality': (highQuality ?? false) ? 'hd' : 'standard',
        'style': (style ?? ImageStyle.vivid).toString(),
        'size': (size ?? ImageSize.square1024).toString(),
      },
    );
    Map<String, dynamic> map = response.data;
    var data = map.getList('data', (item) => item['url'] as String);
    var item = data.single;
    var downloadResponse = await dio.get(
      item,
      options: Options(
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: onDownloadProgress == null
          ? null
          : (count, total) {
              onDownloadProgress(count / total);
            },
    );
    return downloadResponse.data;
  }
}
