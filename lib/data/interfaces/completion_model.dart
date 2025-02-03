import 'dart:async';

import 'package:vit_gpt_dart_api/data/errors/completion_exception.dart';

import '../models/message.dart';

abstract class CompletionModel {
  /// Indicates the class adds the response message to the current thread.
  ///
  /// Meaning that classes using this model don't need to manually add the
  /// model message.
  bool get addsResponseAutomatically;

  bool get addsPreviousMessagesToThread;

  Future<Message> fetch({
    List<Message>? previousMessages,
  });

  Stream<String> fetchStream({
    List<Message>? previousMessages,
    int retries = 2,
    FutureOr<void> Function(
      CompletionException error,
      int retriesRemaning,
    )? onError,
    void Function(Map<String, dynamic> chunk)? onJsonComplete,
  });
}
