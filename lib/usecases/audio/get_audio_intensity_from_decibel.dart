/// Calculates the intensity of an audio unit in decibels.
///
/// [value] should be a negative number representing the decibels. This value
/// should not be above [maximum] or below [minimum].
double getAudioIntensityFromDecibel({
  required double value,
  double maximum = 0,
  double minimum = -70,
}) {
  assert(value <= 0);
  assert(value <= maximum);
  assert(value >= minimum);

  var percent = (value - minimum) / (maximum - minimum);

  // Limits the percentage to 0 and 1.
  if (percent < 0) {
    percent = 0;
  } else if (percent > 1) {
    percent = 1;
  }

  return percent;
}
