import 'package:vit_gpt_dart_api/data/errors/completion_exception.dart';

import '../models/message.dart';

abstract class CompletionModel {
  /// Indicates the class adds the response message to the current thread.
  ///
  /// Meaning that classes using this model don't need to manually add the
  /// model message.
  bool get addsResponseAutomatically;

  Future<Message> fetch();

  Stream<String> fetchStream({
    int retries = 2,
    void Function(CompletionException error, int retriesRemaning)? onError,
  });
}
