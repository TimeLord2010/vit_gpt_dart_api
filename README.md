# VIT GPT Dart API

A streamlined Dart package for accessing OpenAI's API directly from your Dart and Flutter applications. This client simplifies the integration of powerful AI technologies, enabling developers to focus on building innovative solutions.

## Features

- **Model Customization**: Choose from a range of OpenAI models, including the latest versions of ChatGPT
- **Interactive Assistants**: Build and manage virtual assistants with human-like conversational abilities
- **Conversation Management**: Create and control conversation flows with ease
- **Streaming Support**: Real-time response streaming for better user experience
- **Persistent Configurations**: Save and retrieve configurations on disk to maintain session continuity

## Quick Start

```dart
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_dart_api/factories/create_completion_repository.dart';

Future<void> main() async {
  // Set your OpenAI API token
  String token = 'YOUR_OPENAI_TOKEN';
  await updateApiToken(token);

  // Create a completion repository
  CompletionModel completion = createCompletionRepository();

  // Send a message and get a response
  var response = await completion.fetch(
    previousMessages: [
      Message.user(message: 'Hello, how are you?'),
    ],
  );

  print(response.text);
}
```
