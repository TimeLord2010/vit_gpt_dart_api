import 'dart:math';
import 'dart:typed_data';

/// Returns a maximum of 32767.
double getAudioIntensity(Uint8List data) {
  int n = data.length;
  if (n == 0) return 0.0;

  double sum = 0.0;
  for (int i = 0; i < n; i += 2) {
    // Assuming 16-bit PCM
    int sampleValue = (data[i] & 0xff) | ((data[i + 1] & 0xff) << 8);
    sampleValue = sampleValue > 32767 ? sampleValue - 65536 : sampleValue;
    sum += sampleValue * sampleValue;
  }
  return sqrt(sum / (n / 2));
}
