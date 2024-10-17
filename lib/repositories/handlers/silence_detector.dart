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
  final int _sample = 40;

  /// The amount of samples that have a constant amount of silence or loud noise
  /// to begin to conside a "Period of silence" or "Period of loud sounds".
  final int _threshold = 10;

  /// [decibelsStream] is a stream of microphone intensities changes received
  /// every X amount of time. The values are negative, where values closer to
  /// zero mean the microphone is picking a loud sound.
  ///
  /// The catch is that the mimumum and maximum values depend on the microphone
  /// used by the user.
  SilenceDetector({
    required Stream<double> decibelsStream,
  }) {
    assert(_sample > 2 * _threshold);
    decibelsStream.listen((intensity) {
      _pump(intensity);
      _checkSilenceChanged();
    });
  }

  void clear() {
    _history.clear();
  }

  double _calculateMaxSilenceIntensity() {
    if (_history.isEmpty) {
      return -50.0; // Default to a very low intensity if history is empty
    }

    // Calculate the average of the quieter 10% samples to determine max silence intensity
    List<double> sortedHistory = List.from(_history)..sort();
    int numberOfSamplesToConsider = (0.2 * sortedHistory.length).round();
    var quietestSamples =
        sortedHistory.take(numberOfSamplesToConsider).toList();

    return quietestSamples.last;
  }

  void _checkSilenceChanged() {
    if (_history.length < _sample) {
      var remaining = _sample - _history.length;
      logger.warn(
          '(SilenceDetector): Not enough samples ($remaining remaining).');
      return;
    }

    // Calculate the range within the relevant samples to detect overlapping values
    double minValue = _history.reduce((a, b) => a < b ? a : b);
    double maxValue = _history.reduce((a, b) => a > b ? a : b);
    double range = maxValue - minValue;

    // Introduce a threshold below which no events are considered; adjust this value as appropriate
    double varianceThreshold = 10;

    if (range < varianceThreshold) {
      logger.warn('(SilenceDetector) Not enough variance: $range');
      return; // Do not emit any events if the variance is below the threshold
    }

    /// The maximum amount of decibels that are considered silence.
    double maxSilenceIntensity = _calculateMaxSilenceIntensity();

    var lastSamples =
        _history.skip(_history.length - (2 * _threshold)).take(_threshold);
    var relevantSamples = _history.skip(_history.length - _threshold);

    bool isSampleSilent(Iterable<double> sample) {
      // Define a function for checking if a sample is considered silent
      bool isValueSilent(double sample) {
        return sample < maxSilenceIntensity;
      }

      return sample.where(isValueSilent).length >= 0.9 * sample.length;
    }

    // Determine if currently silent by checking if at least 90% of relevantSamples are silent
    bool isCurrentlySilent = isSampleSilent(relevantSamples);

    // Determine if we were just in a silent state by similar logic
    bool wasPreviouslySilent = isSampleSilent(lastSamples);

    // Signal a transition to loud if we were previously silent but are not anymore
    if (wasPreviouslySilent && !isCurrentlySilent) {
      silenceController.add(false); // End of silence
    }

    // Signal a transition to silence if it was loud previously
    if (!wasPreviouslySilent && isCurrentlySilent) {
      silenceController.add(true); // Beginning of silence
    }
  }

  void _pump(double value) {
    _history.add(value);
    while (_history.length > _sample) {
      _history.removeAt(0);
    }
  }

  void dispose() {
    _history.clear();
    silenceController.close();
  }
}
