import '../data/enums/role.dart';
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

  Future<void> prompt({
    String? message,
    List<Message>? previousMessages,
    required void Function(Message message, String chunk) onChunk,
    void Function(Message msg)? onMessageCreated,
    void Function(Object error)? onMessageCreateError,
  }) async {
    var threadId = conversation.id!;

    // Adding the message sent
    Message? selfMessage;
    if (message != null) {
      selfMessage = Message(
        date: DateTime.now(),
        text: message,
        role: Role.user,
      );
      conversation.messages.add(selfMessage);
    }

    // Creating message object to update on every chunk.
    var msg = Message(
      date: DateTime.now(),
      text: '',
      role: Role.assistant,
    );
    conversation.messages.add(msg);

    // Obtaining stream of characters of the response.
    var stream = completion.fetchStream(
      onError: onError,
      retries: retries,
      onJsonComplete: onJsonComplete,
      previousMessages: [
        if (selfMessage != null) selfMessage,
        ...previousMessages ?? [],
      ],
    );
    await for (var chunk in stream) {
      msg.text += chunk;
      onChunk(msg, chunk);
    }

    /// We don't need to wait for this.
    /// Use [onMessageCreated] if necessary.
    Future<void> createMessage(Message msg) async {
      try {
        if (msg.text.isEmpty) {
          throw Exception('Message text is empty');
        }
        await threads.sendMessage(threadId, msg);
        if (onMessageCreated != null) onMessageCreated(msg);
      } catch (e) {
        if (onMessageCreateError != null) onMessageCreateError(e);
      }
    }

    if (!completion.addsPreviousMessagesToThread) {
      Future<void> createPreviousMessages() async {
        for (var pm in previousMessages ?? []) {
          await createMessage(pm);
        }
        if (selfMessage != null) await createMessage(selfMessage);
      }

      createPreviousMessages();
    }

    // Saving response message to the thread
    if (!completion.addsResponseAutomatically) {
      createMessage(msg);
    }
  }
}
