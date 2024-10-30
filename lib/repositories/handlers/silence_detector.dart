import 'dart:async';

import 'package:vit_gpt_dart_api/factories/logger.dart';

/// Processes the stream of microphone intensity to notify when a silence
/// period begins of ends based on the values received.
///
/// The class achieves its purpose by:
/// - Receiving a continuous stream of decibel levels from the microphone.
/// - Maintaining a history of recent intensity values to analyze patterns.
/// - Detecting transitions between silence and non-silence based on the calculated threshold, considering at least 90% of samples as silent to confirm a silent period.
/// - Signaling via a `StreamController` when silence begins or ends.
class SilenceDetector {
  final _silenceController = StreamController<bool>();

  /// A list of samples of the latests microphone intensities.
  final List<double> _history = [];

  /// The amount of instances of the microphone to keep in the [_history] list.
  static int totalSamplesToKeep = 20;

  /// The amount of samples that have a constant amount of silence or loud noise
  /// to begin to conside a "Period of silence" or "Period of loud sounds".
  static int minSilenceCount = 6;

  // Threshold below which no events are considered.
  static double minimumVariance = 10;

  /// The minimum percentage of silence a list of values can have as silence
  /// to be considered a period of silence.
  /// This value is rounded up in case of floating point result.
  static double minPercentTolerance = 0.9;

  /// [decibelsStream] is a stream of microphone intensities changes received
  /// every X amount of time. The values are negative, where values closer to
  /// zero mean the microphone is picking a loud sound.
  ///
  /// The catch is that the mimumum and maximum values depend on the microphone
  /// used by the user.
  SilenceDetector({
    required Stream<double> decibelsStream,
  }) {
    assert(totalSamplesToKeep > 2 * minSilenceCount);
    decibelsStream.listen((intensity) {
      _pump(intensity);
      _checkSilenceChanged();
    });
  }

  Stream<bool> get stream => _silenceController.stream;

  void _checkSilenceChanged() {
    if (!_canProcess()) {
      return;
    }

    /// The maximum amount of decibels that are considered silence.
    double maxSilenceIntensity = getMaxSilenceIntensity();

    Iterable<double> lastSamples = _history
        .skip(_history.length - (2 * minSilenceCount))
        .take(minSilenceCount);
    Iterable<double> relevantSamples =
        _history.skip(_history.length - minSilenceCount);

    // Define a function for checking if a sample is considered silent
    bool isValueSilent(double sample) => sample <= maxSilenceIntensity;

    bool isSampleSilent(Iterable<double> sample) {
      int other = (minPercentTolerance * sample.length).ceil();
      return sample.where(isValueSilent).length >= other;
    }

    // Determine if currently silent by checking if at least some percentage of
    // relevantSamples are silent.
    bool isCurrentlySilent = isSampleSilent(relevantSamples);

    // Determine if we were just in a silent state by similar logic
    bool wasPreviouslySilent = isSampleSilent(lastSamples);

    // Signal a transition to loud if we were previously silent but are not anymore
    if (wasPreviouslySilent && !isCurrentlySilent) {
      _silenceController.add(false); // End of silence
    }

    // Signal a transition to silence if it was loud previously
    if (!wasPreviouslySilent && isCurrentlySilent) {
      _silenceController.add(true); // Beginning of silence
    }
  }

  /// Checks if the current state is processable.
  ///
  /// The state is processable if:
  /// - The history list has enough values.
  /// - The values have enought variance (Preventing samples with full silence
  /// or full loud sounds from being processed).
  bool _canProcess() {
    // Check if there is enough values
    var requiredCount = (minSilenceCount * 2) + 1;
    if (_history.length < requiredCount) {
      var remaining = requiredCount - _history.length;
      logger.warn(
          '(SilenceDetector): Not enough samples ($remaining remaining).');
      return false;
    }

    // Check if the values have enough variance.
    // If not, it must mean that the values consist on all silence or loud
    // sounds.
    double minValue = _history.reduce((a, b) => a < b ? a : b);
    double maxValue = _history.reduce((a, b) => a > b ? a : b);
    double range = maxValue - minValue;

    if (range < minimumVariance) {
      logger.warn('(SilenceDetector) Not enough variance: $range');
      return false;
    }

    return true;
  }

  /// Calculates the maximum value that is considered silence.
  ///
  /// This function will calculate the variance between each adjance value in
  /// the history.
  ///
  /// At the interval where the variance is the greatest, the lower value is
  /// considered silence. But half of the variance is added to this value as
  /// a safe guard.
  double getMaxSilenceIntensity() {
    if (_history.isEmpty) {
      return -50.0; // Default silence threshold when history is empty
    }

    if (_history.length < 2) {
      return -20;
    }

    int varianceIndex = 0;
    double maxVariance = -1;

    double addVariance(double variance) => variance / 2;

    for (int i = 0; i < _history.length - 1; i++) {
      var first = _history[i];
      var second = _history[i + 1];
      var currentVariance = (first - second).abs();
      if (currentVariance > maxVariance) {
        // 20 is considered a loud sound. So it cannot be considered silence
        if ((first + addVariance(currentVariance)) > -20) {
          continue;
        }

        varianceIndex = i;
        maxVariance = currentVariance;
      }
    }

    if (maxVariance == -1) {
      return _history.first;
    }

    var first = _history[varianceIndex];
    var second = _history[varianceIndex + 1];

    var silenceValue = (first > second ? second : first).toInt();

    var other = addVariance(maxVariance).toInt();
    var total = silenceValue + other;

    logger.debug(
        '(SilenceDetector) Max silence = $total ($silenceValue + $other)');
    return total.toDouble();
  }

  /// Adds the latest value to the history list.
  ///
  /// If the history size is greater than the allowed lenght, the first item
  /// is removed.
  void _pump(double value) {
    _history.add(value);
    while (_history.length > totalSamplesToKeep) {
      _history.removeAt(0);
    }
  }

  void clear() => _history.clear();

  void dispose() {
    clear();
    _silenceController.close();
  }
}
