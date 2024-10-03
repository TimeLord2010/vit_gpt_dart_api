import 'package:chatgpt_chat/data/enums/sender_type.dart';
import 'package:chatgpt_chat/data/interfaces/completion_model.dart';
import 'package:chatgpt_chat/data/interfaces/threads_model.dart';
import 'package:chatgpt_chat/data/models/conversation.dart';
import 'package:chatgpt_chat/data/models/message.dart';

class ConversationRepository {
  final Conversation conversation;
  final CompletionModel completion;
  final ThreadsModel threads;

  /// Amount of messages to send the to completion model.
  final int amountToSend = 15;

  ConversationRepository({
    required this.completion,
    required this.conversation,
    required this.threads,
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

    // Fetching [amountToSend] messages to request completion.
    var messages = [...conversation.messages];
    if (messages.length > amountToSend) {
      messages = messages.skip(messages.length - amountToSend).toList();
    }

    // Creating message object to update on every chunk.
    var msg = Message(
      date: DateTime.now(),
      text: '',
      sender: SenderType.assistant,
    );
    conversation.messages.add(msg);

    // Obtaining stream of characters.
    var stream = completion.fetchStream(
      messages: messages,
    );
    await for (var chunk in stream) {
      msg.text += chunk;
      onChunk(msg, chunk);
    }
    await threads.sendMessage(threadId, msg);
  }
}
