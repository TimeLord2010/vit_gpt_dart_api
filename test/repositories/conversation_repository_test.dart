import 'dart:async';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vit_gpt_dart_api/data/enums/role.dart';
import 'package:vit_gpt_dart_api/data/errors/completion_exception.dart';
import 'package:vit_gpt_dart_api/data/interfaces/completion_model.dart';
import 'package:vit_gpt_dart_api/data/interfaces/threads_model.dart';
import 'package:vit_gpt_dart_api/data/models/conversation.dart';
import 'package:vit_gpt_dart_api/data/models/message.dart';
import 'package:vit_gpt_dart_api/repositories/conversation_repository.dart';

// dart run build_runner build

import 'conversation_repository_test.mocks.dart';

@GenerateMocks([CompletionModel, ThreadsModel])
void main() {
  group('ConversationRepository', () {
    late Conversation conversation;
    late MockCompletionModel mockCompletion;
    late MockThreadsModel mockThreads;
    late ConversationRepository repository;

    setUp(() {
      conversation = Conversation(id: 'testId');
      mockCompletion = MockCompletionModel();
      mockThreads = MockThreadsModel();

      // Stub methods on mockCompletion
      when(mockCompletion.fetchStream()).thenAnswer((_) {
        return Stream.fromIterable(['Hello', ' World']);
      });
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(true);
      when(mockCompletion.addsResponseAutomatically).thenReturn(true);

      repository = ConversationRepository(
        completion: mockCompletion,
        conversation: conversation,
        threads: mockThreads,
      );
    });

    test('should add user message to conversation', () async {
      when(mockCompletion.fetchStream()).thenAnswer((_) {
        return Stream.fromIterable(['Hello', ' World']);
      });

      await repository.prompt(
          message: 'Hi there', onChunk: (message, chunk) {});

      expect(conversation.messages.length, equals(2));
      expect(conversation.messages.first.text, equals('Hi there'));
      expect(conversation.messages.first.role, equals(Role.user));
    });

    test('should send user message when addsPreviousMessagesToThread is false',
        () async {
      // Arrange
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(false);

      // Act
      await repository.prompt(
          message: 'Hi there', onChunk: (message, chunk) {});

      // Assert
      // Verify that threads.sendMessage was called with the user's message
      var verification = verify(mockThreads.createMessage(
        captureAny, // Captures threadId
        captureAny, // Captures message
      ));
      expect(verification.callCount, 1);
      var capturedArgs = verification.captured;
      expect(capturedArgs[0], conversation.id);
      Message sentMessage = capturedArgs[1];
      expect(sentMessage.text, 'Hi there');
      expect(sentMessage.role, Role.user);
    });

    test(
        'should send assistant message when addsResponseAutomatically is false',
        () async {
      // Arrange
      when(mockCompletion.addsResponseAutomatically).thenReturn(false);

      // Act
      await repository.prompt(
          message: 'Hi there', onChunk: (message, chunk) {});

      // Assert
      // Verify that threads.sendMessage was called with the assistant's message
      var verification = verify(mockThreads.createMessage(
        captureAny, // Captures threadId
        captureAny, // Captures message
      ));
      expect(verification.callCount, 1);
      var capturedArgs = verification.captured;
      expect(capturedArgs[0], conversation.id);
      Message sentMessage = capturedArgs[1];
      expect(sentMessage.text, 'Hello World'); // Because 'Hello' + ' World'
      expect(sentMessage.role, Role.assistant);
    });

    test('should handle exception when sending message fails', () async {
      // Arrange
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(false);
      var error = Exception('Network error');
      when(mockThreads.createMessage(any, any)).thenThrow(error);

      Object? capturedError;
      void onMessageCreateError(Object e) {
        capturedError = e;
      }

      // Act
      await repository.prompt(
        message: 'Hi there',
        onChunk: (message, chunk) {},
        onMessageCreateError: onMessageCreateError,
      );

      // Assert
      expect(capturedError, isNotNull);
      expect(capturedError, equals(error));
    });

    test('should call onMessageCreated when message is successfully sent',
        () async {
      // Arrange
      when(mockThreads.createMessage(any, any)).thenAnswer((_) async {
        return Message(
          date: DateTime.now(),
          text: '',
          role: Role.user,
        );
      });
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(false);

      Message? createdMessage;
      var completer = Completer();

      void onMessageCreated(Message msg) {
        createdMessage = msg;
        completer.complete();
      }

      // Act
      await repository.prompt(
        message: 'Hi there',
        onChunk: (message, chunk) {},
        onMessageCreated: onMessageCreated,
      );

      await completer.future.timeout(Duration(seconds: 1));

      // Assert
      expect(createdMessage, isNotNull);
      expect(createdMessage!.text, 'Hi there');
    });

    test('should handle empty message text when creating message', () async {
      // Arrange
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(true);
      when(mockCompletion.addsResponseAutomatically).thenReturn(false);
      when(mockThreads.createMessage(any, any)).thenAnswer((_) async {
        return Message(
          date: DateTime.now(),
          text: '',
          role: Role.user,
        );
      });

      // Simulate that the assistant's message text remains empty
      when(mockCompletion.fetchStream()).thenAnswer((_) {
        return Stream<String>.empty();
      });

      Object? capturedError;
      var completer = Completer();
      void onMessageCreateError(Object e) {
        capturedError = e;
        completer.complete();
      }

      // Act
      await repository.prompt(
        message: 'Hi there',
        onChunk: (message, chunk) {},
        onMessageCreateError: onMessageCreateError,
      );

      await completer.future.timeout(Duration(seconds: 1));

      // Assert
      expect(capturedError, isNotNull);
      expect(capturedError, isException);
      expect((capturedError as Exception).toString(),
          contains('Message text is empty'));
    });

    test('should call onError with CompletionException when fetchStream fails',
        () async {
      // Arrange
      var completionException = CompletionException('500', 'Completion failed');
      when(mockCompletion.fetchStream(
        onError: anyNamed('onError'),
        retries: anyNamed('retries'),
        onJsonComplete: anyNamed('onJsonComplete'),
      )).thenAnswer((Invocation invocation) {
        // Capture the onError callback
        var onErrorCallback = invocation.namedArguments[const Symbol('onError')]
            as void Function(
                CompletionException exception, int remainingRetries)?;

        // Simulate fetchStream calling onError
        if (onErrorCallback != null) {
          onErrorCallback(completionException, 1);
        }

        // Return an empty stream
        return Stream<String>.empty();
      });
      when(mockCompletion.addsPreviousMessagesToThread).thenReturn(true);
      when(mockCompletion.addsResponseAutomatically).thenReturn(true);

      CompletionException? capturedException;
      int? capturedRemainingRetries;
      var completer = Completer();
      void onError(CompletionException exception, int remainingRetries) {
        capturedException = exception;
        capturedRemainingRetries = remainingRetries;
        completer.complete();
      }

      repository = ConversationRepository(
        completion: mockCompletion,
        conversation: conversation,
        threads: mockThreads,
        onError: onError,
        retries: 1,
      );

      // Act
      try {
        await repository.prompt(
            message: 'Hi there', onChunk: (message, chunk) {});
      } catch (e) {
        // The prompt method may rethrow the exception after retries are exhausted
      }

      await completer.future.timeout(Duration(seconds: 1));

      // Assert
      expect(capturedException, isNotNull);
      expect(capturedException, equals(completionException));
      expect(capturedRemainingRetries, equals(1));
    });

    test('should call onJsonComplete when completion returns JSON', () async {
      // Arrange
      Map<String, dynamic> jsonResponse = {'key': 'value'};
      when(mockCompletion.fetchStream(
        onError: anyNamed('onError'),
        retries: anyNamed('retries'),
        onJsonComplete: anyNamed('onJsonComplete'),
      )).thenAnswer((Invocation invocation) {
        var onJsonComplete =
            invocation.namedArguments[const Symbol('onJsonComplete')] as void
                Function(Map<String, dynamic>)?;
        if (onJsonComplete != null) {
          onJsonComplete(jsonResponse);
        }
        return Stream.fromIterable(['Hello', ' World']);
      });

      Map<String, dynamic>? capturedJson;
      void onJsonComplete(Map<String, dynamic> json) {
        capturedJson = json;
      }

      repository = ConversationRepository(
        completion: mockCompletion,
        conversation: conversation,
        threads: mockThreads,
        onJsonComplete: onJsonComplete,
      );

      // Act
      await repository.prompt(
        message: 'Hi there',
        onChunk: (message, chunk) {},
      );

      // Assert
      expect(capturedJson, isNotNull);
      expect(capturedJson, equals(jsonResponse));
    });
  });
}
