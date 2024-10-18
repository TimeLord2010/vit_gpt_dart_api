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
  final silenceController = StreamController<bool>();

  /// A list of samples of the latests microphone intensities.
  final List<double> _history = [];

  /// The amount of instances of the microphone to keep in the [_history] list.
  static final int totalSamplesToKeep = 20;

  /// The amount of samples that have a constant amount of silence or loud noise
  /// to begin to conside a "Period of silence" or "Period of loud sounds".
  static final int minSilenceCount = 6;

  // Threshold below which no events are considered.
  static final double minimumVariance = 10;

  /// The minimum percentage of silence a list of values can have as silence
  /// to be considered a period of silence.
  /// This value is rounded up in case of floating point result.
  static final double minPercentTolerance = 0.9;

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

  void _checkSilenceChanged() {
    if (!_canProcess()) {
      return;
    }

    /// The maximum amount of decibels that are considered silence.
    double maxSilenceIntensity = _calculateMaxSilenceIntensity();
    logger.debug('Max silence: $maxSilenceIntensity');

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

    // Determine if currently silent by checking if at least 90% of relevantSamples are silent
    bool isCurrentlySilent = isSampleSilent(relevantSamples);

    // Determine if we were just in a silent state by similar logic
    bool wasPreviouslySilent = isSampleSilent(lastSamples);

    logger.debug('(SilenceDetector): $_history');

    var items = _history.map((x) => isValueSilent(x)).toList();
    logger.debug('(SilenceDetector): $items');

    logger.debug(
        '(SilenceDetector): current: $isCurrentlySilent. Last: $wasPreviouslySilent');

    // Signal a transition to loud if we were previously silent but are not anymore
    if (wasPreviouslySilent && !isCurrentlySilent) {
      silenceController.add(false); // End of silence
    }

    // Signal a transition to silence if it was loud previously
    if (!wasPreviouslySilent && isCurrentlySilent) {
      silenceController.add(true); // Beginning of silence
    }
  }

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
      return false; // Do not emit any events if the variance is below the threshold
    }

    return true;
  }

  double _calculateMaxSilenceIntensity() {
    if (_history.isEmpty) {
      return -50.0; // Default silence threshold when history is empty
    }

    int varianceIndex = 0;
    double maxVariance = -1;

    for (int i = 0; i < _history.length - 1; i++) {
      var first = _history[i];
      var second = _history[i + 1];
      var currentVariance = (first - second).abs();

      if (currentVariance > maxVariance) {
        varianceIndex = i;
        maxVariance = currentVariance;
      }
    }

    if (maxVariance == -1) {
      throw Exception('Max variance not calculated correctly');
    }

    var first = _history[varianceIndex];
    var second = _history[varianceIndex + 1];

    var silenceValue = first > second ? second : first;

    return silenceValue + (maxVariance / 2);
    //return silenceValue + 5;

    // List<double> sortedHistory = List.from(_history)..sort();
    // int lowerIndex = (0.1 * sortedHistory.length).round();
    // int upperIndex = (0.9 * sortedHistory.length).round();

    // // Select middle 80% of values to discard extremes
    // List<double> trimmedSamples = sortedHistory.sublist(lowerIndex, upperIndex);

    // // Calculate the median of the trimmed list instead of an average
    // double median;
    // int length = trimmedSamples.length;
    // if (length % 2 == 1) {
    //   median = trimmedSamples[length ~/ 2];
    // } else {
    //   median =
    //       (trimmedSamples[length ~/ 2 - 1] + trimmedSamples[length ~/ 2]) / 2.0;
    // }

    // return median;
  }

  void _pump(double value) {
    _history.add(value);
    while (_history.length > totalSamplesToKeep) {
      _history.removeAt(0);
    }
  }

  void clear() => _history.clear();

  void dispose() {
    clear();
    silenceController.close();
  }
}
