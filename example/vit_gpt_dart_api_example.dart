import 'dart:async';

import 'package:vit_gpt_dart_api/factories/create_completion_repository.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

Future<void> main() async {
  String token = 'MY OPEN AI TOKEN';
  await updateApiToken(token);

  // Simple response from AI

  CompletionModel completion = createCompletionRepository();

  var newMessage = await completion.fetch(
    previousMessages: [
      Message.user(
        message: 'How much is 2 + 2?',
      ),
    ],
  );

  print(newMessage.text);

  // Reading response as stream

  var stream = completion.fetchStream(
    previousMessages: [
      Message.user(
        message: 'How much is 2 + 2?',
      ),
    ],
  );

  await for (var chunk in stream) {
    print(chunk);
  }

  // Using custom completion model

  DynamicFactories.completion = () => CustomCompletionModel();

  completion = createCompletionRepository();

  newMessage = await completion.fetch(
    previousMessages: [
      Message.user(
        message: 'How much is 2 + 2?',
      ),
    ],
  );
  print(newMessage.text);
}

class CustomCompletionModel extends CompletionModel {
  @override
  // Only relevant if working with OpenAI threads and using the assistant run.
  bool get addsPreviousMessagesToThread => false;

  @override
  // Only relevant if working with OpenAI threads and using the assistant run.
  bool get addsResponseAutomatically => false;

  @override
  Future<Message> fetch({List<Message>? previousMessages}) async {
    return Message.assistant(
      message: 'This is a custom response',
    );
  }

  @override
  Stream<String> fetchStream(
      {List<Message>? previousMessages,
      int retries = 2,
      FutureOr<void> Function(CompletionException error, int retriesRemaning)?
          onError,
      void Function(Map<String, dynamic> chunk)? onJsonComplete}) {
    // TODO: implement fetchStream
    throw UnimplementedError();
  }
}
