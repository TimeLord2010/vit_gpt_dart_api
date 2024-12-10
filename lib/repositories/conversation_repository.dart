import '../data/enums/sender_type.dart';
import '../data/errors/completion_exception.dart';
import '../data/interfaces/completion_model.dart';
import '../data/interfaces/threads_model.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';

/// Handles the flow of asking and streaming the response.
class ConversationRepository {
  final Conversation conversation;
  final CompletionModel completion;
  final ThreadsModel threads;

  final int retries;
  final void Function(CompletionException exception, int remainingRetries)?
      onError;
  final void Function(Map<String, dynamic>)? onJsonComplete;

  ConversationRepository({
    required this.completion,
    required this.conversation,
    required this.threads,
    this.onError,
    this.onJsonComplete,
    this.retries = 2,
  });

  Future<void> prompt(
    String message, {
    required void Function(Message message, String chunk) onChunk,
    void Function()? onFirstMessageCreated,
  }) async {
    var threadId = conversation.id!;

    // Adding the message sent
    var selfMessage = Message(
      date: DateTime.now(),
      text: message,
      sender: SenderType.user,
    );
    conversation.messages.add(selfMessage);
    if (onFirstMessageCreated != null) onFirstMessageCreated();
    await threads.sendMessage(threadId, selfMessage);

    // Creating message object to update on every chunk.
    var msg = Message(
      date: DateTime.now(),
      text: '',
      sender: SenderType.assistant,
    );
    conversation.messages.add(msg);

    // Obtaining stream of characters of the response.
    var stream = completion.fetchStream(
      onError: onError,
      retries: retries,
      onJsonComplete: onJsonComplete,
    );
    await for (var chunk in stream) {
      msg.text += chunk;
      onChunk(msg, chunk);
    }

    // Saving message to the thread
    if (completion.addsResponseAutomatically) {
      return;
    }

    if (msg.text.isEmpty) {
      return;
    }

    await threads.sendMessage(threadId, msg);
  }
}
