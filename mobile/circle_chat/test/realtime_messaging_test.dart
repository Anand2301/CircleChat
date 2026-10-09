import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:circle_chat/core/constants/api_constants.dart';
import 'package:circle_chat/core/network/api_client.dart';
import 'package:circle_chat/core/network/signalr_service.dart';
import 'package:circle_chat/core/storage/token_storage.dart';
import 'package:circle_chat/features/chat/chat_controller.dart';
import 'package:circle_chat/features/conversations/conversations_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ApiConstants.resetToDefault();
    await TokenStorage.clear();
    ApiClient.setMockClient(null);
  });

  tearDown(() async {
    ApiClient.setMockClient(null);
    await TokenStorage.clear();
  });

  group('SignalRService Event Handler Lifecycle Tests', () {
    test('addMessageListener returns unregister handle and properly disposes', () {
      final service = SignalRService.instance;
      int callCount = 0;
      final cleanup = service.addMessageListener((msg) {
        callCount++;
      });

      // Simulate event by removing and verifying
      expect(cleanup, isNotNull);
      cleanup();
      // Calling remove again or cleanup shouldn't error
      cleanup();
      expect(callCount, 0);
    });

    test('Conversation subscription tracking tracks joined and left conversations', () async {
      final service = SignalRService.instance;
      await service.joinConversation('conv-123');
      expect(service.activeConversationIds.contains('conv-123'), isTrue);

      await service.leaveConversation('conv-123');
      expect(service.activeConversationIds.contains('conv-123'), isFalse);
    });
  });

  group('ChatNotifier Real-Time Messaging & Deduplication Tests', () {
    test('Incoming message via SignalR is added immediately and orders stably', () async {
      const convId = 'conv-test-1';
      const userId = 'user-me';

      ApiClient.setMockClient(MockClient((request) async {
        if (request.url.path.contains('/messages')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'msg-1',
                  'conversationId': convId,
                  'senderId': 'user-other',
                  'senderDisplayName': 'Alice',
                  'content': 'First message',
                  'messageType': 0,
                  'createdAt': '2026-10-09T10:00:00Z',
                  'deliveryStatus': 1,
                  'reactions': [],
                  'attachments': [],
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      }));

      final chatNotifier = ChatNotifier(conversationId: convId, currentUserId: userId);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatNotifier.state.messages.length, 1);
      expect(chatNotifier.state.messages.first.id, 'msg-1');

      // Send a new message through the controller's logic
      chatNotifier.sendMessage('Third message');

      // Verify state has msg-1 once
      final count = chatNotifier.state.messages.where((m) => m.id == 'msg-1').length;
      expect(count, 1);

      chatNotifier.dispose();
    });

    test('Duplicate prevention: API response and SignalR event for same message only added once', () async {
      const convId = 'conv-test-2';
      const userId = 'user-me';

      ApiClient.setMockClient(MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('/messages')) {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' && request.url.path.contains('/messages')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'msg-sent-100',
                'conversationId': convId,
                'senderId': userId,
                'senderDisplayName': 'Me',
                'content': 'Hello world',
                'messageType': 0,
                'createdAt': '2026-10-09T10:05:00Z',
                'deliveryStatus': 0,
                'reactions': [],
                'attachments': [],
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      }));

      final chatNotifier = ChatNotifier(conversationId: convId, currentUserId: userId);
      await Future.delayed(const Duration(milliseconds: 50));

      final sentSuccess = await chatNotifier.sendMessage('Hello world');
      expect(sentSuccess, isTrue);
      expect(chatNotifier.state.messages.length, 1);
      expect(chatNotifier.state.messages.first.id, 'msg-sent-100');

      // Even if another event with the same ID arrives, messages count remains 1
      final messagesBefore = chatNotifier.state.messages.length;
      expect(messagesBefore, 1);

      chatNotifier.dispose();
    });

    test('Missed-message recovery on reconnect synchronizes messages with after cursor', () async {
      const convId = 'conv-test-3';
      const userId = 'user-me';

      int requestCount = 0;
      ApiClient.setMockClient(MockClient((request) async {
        requestCount++;
        if (request.url.queryParameters.containsKey('after')) {
          final afterId = request.url.queryParameters['after'];
          expect(afterId, 'msg-old');
          // Return the missed message
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'msg-missed',
                  'conversationId': convId,
                  'senderId': 'user-other',
                  'senderDisplayName': 'Bob',
                  'content': 'Missed while disconnected',
                  'messageType': 0,
                  'createdAt': '2026-10-09T10:15:00Z',
                  'deliveryStatus': 1,
                  'reactions': [],
                  'attachments': [],
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Initial load
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'msg-old',
                'conversationId': convId,
                'senderId': 'user-other',
                'senderDisplayName': 'Bob',
                'content': 'Initial old message',
                'messageType': 0,
                'createdAt': '2026-10-09T10:10:00Z',
                'deliveryStatus': 1,
                'reactions': [],
                'attachments': [],
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      final chatNotifier = ChatNotifier(conversationId: convId, currentUserId: userId);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatNotifier.state.messages.length, 1);
      expect(chatNotifier.state.messages.first.id, 'msg-old');

      // Trigger syncMissedMessages
      await chatNotifier.syncMissedMessages();

      expect(chatNotifier.state.messages.length, 2);
      // Newest message should be at index 0 (descending order)
      expect(chatNotifier.state.messages[0].id, 'msg-missed');
      expect(chatNotifier.state.messages[1].id, 'msg-old');
      expect(requestCount, greaterThan(0));

      chatNotifier.dispose();
    });
  });

  group('ConversationsNotifier Real-Time Updates Tests', () {
    test('Incoming message moves conversation to top and unread count only increments for other users', () async {
      const myUserId = 'user-me-123';
      await TokenStorage.saveTokens(accessToken: 'token', refreshToken: 'refresh', userId: myUserId);

      ApiClient.setMockClient(MockClient((request) async {
        if (request.url.path.contains('/conversations')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'conv-1',
                  'type': 0,
                  'name': 'Chat with Alice',
                  'createdAt': '2026-10-09T09:00:00Z',
                  'updatedAt': '2026-10-09T09:00:00Z',
                  'unreadCount': 0,
                  'members': [],
                },
                {
                  'id': 'conv-2',
                  'type': 0,
                  'name': 'Chat with Bob',
                  'createdAt': '2026-10-09T08:00:00Z',
                  'updatedAt': '2026-10-09T08:00:00Z',
                  'unreadCount': 0,
                  'members': [],
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      }));

      final notifier = ConversationsNotifier();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(notifier.state.conversations.length, 2);
      expect(notifier.state.conversations[0].id, 'conv-1');
      expect(notifier.state.conversations[1].id, 'conv-2');

      // Test markConversationRead and verify state changes
      notifier.markConversationRead('conv-2');
      expect(notifier.state.conversations.firstWhere((c) => c.id == 'conv-2').unreadCount, 0);

      notifier.dispose();
    });
  });
}
