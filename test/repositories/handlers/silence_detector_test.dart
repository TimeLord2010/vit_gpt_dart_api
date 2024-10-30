import 'dart:async';
import 'dart:math';

import 'package:test/test.dart';
import 'package:vit_gpt_dart_api/repositories/handlers/silence_detector.dart';

void main() {
  test('should detect single silence', () async {
    // Seting up test
    var model = _TestModel.create();
    var completer = Completer<bool>();
    model.silenceStream.listen((data) => completer.complete(data));

    /// Simulating microphone activity
    var samples = SilenceDetector.totalSamplesToKeep;
    for (int i = 0; i < samples; i++) {
      if (i >= samples - SilenceDetector.minSilenceCount) {
        model.microphoneController.add(-50);
      } else {
        model.microphoneController.add(-20);
      }
    }

    // Checks
    bool isSilent = await completer.future.timeout(Duration(milliseconds: 100));
    expect(
      isSilent,
      true,
      reason: 'Expected silence detection',
    );
  });

  test('should not detect silence if it did not just happened', () async {
    // Seting up test
    var model = _TestModel.create();
    var completer = Completer<bool>();
    model.silenceStream.listen((data) => completer.complete(data));

    /// Simulating microphone activity
    var samples = SilenceDetector.totalSamplesToKeep;
    for (int i = 0; i < samples; i++) {
      if (i == samples - 1) {
        model.microphoneController.add(-20);
        continue;
      }
      if (i >= samples - (SilenceDetector.minSilenceCount + 2)) {
        model.microphoneController.add(-50);
      } else {
        model.microphoneController.add(-20);
      }
    }

    await Future.delayed(Duration(milliseconds: 50));

    // Checks
    expect(
      completer.isCompleted,
      false,
      reason: 'Expected no silence detection',
    );
  });

  test('should detect silence among noise values', () async {
    // Seting up test
    var model = _TestModel.create();
    var completer = Completer<bool>();
    model.silenceStream.listen((data) => completer.complete(data));

    /// Simulating microphone activity
    var samples = SilenceDetector.totalSamplesToKeep;
    var random = Random();
    for (int i = 0; i < samples; i++) {
      if (i >= samples - SilenceDetector.minSilenceCount) {
        double value = (-45 + random.nextInt(10)).toDouble();
        model.microphoneController.add(value);
      } else {
        double value = (-30 + random.nextInt(10)).toDouble();
        model.microphoneController.add(value);
      }
    }

    // Checks
    bool isSilent = await completer.future.timeout(Duration(milliseconds: 100));
    expect(
      isSilent,
      true,
      reason: 'Expected silence detection',
    );
  });
}

class _TestModel {
  final StreamController<double> microphoneController;
  final Stream<bool> silenceStream;

  _TestModel({
    required this.microphoneController,
    required this.silenceStream,
  });

  factory _TestModel.create() {
    var microphoneController = StreamController<double>();
    var detector = SilenceDetector(
      decibelsStream: microphoneController.stream,
    );
    var silenceStream = detector.stream;
    return _TestModel(
      microphoneController: microphoneController,
      silenceStream: silenceStream,
    );
  }
}
