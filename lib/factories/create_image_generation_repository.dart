import '../repositories/image_generation_repository.dart';
import 'http_client.dart';

ImageGenerationRepository createImageGenerationRepository() {
  return ImageGenerationRepository(
    dio: httpClient,
  );
}
