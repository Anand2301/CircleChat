import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:circle_chat/core/constants/api_constants.dart';
import 'package:circle_chat/core/network/api_client.dart';
import 'package:circle_chat/core/network/push_notification_service.dart';
import 'package:circle_chat/core/storage/token_storage.dart';

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

  group('PushNotificationService Device Token Tests', () {
    test('registerDeviceToken does not post if user is unauthenticated', () async {
      int requestCount = 0;
      ApiClient.setMockClient(MockClient((request) async {
        if (request.url.path.contains('/api/devices')) {
          requestCount++;
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('Not Found', 404);
      }));

      // No tokens stored in TokenStorage
      await PushNotificationService.instance.registerDeviceToken('mock-fcm-token-1');

      expect(requestCount, 0);
    });

    test('registerDeviceToken posts token when authenticated and deduplicates same token', () async {
      await TokenStorage.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-123',
        userId: 'user-123',
      );

      int postCount = 0;
      String? postedToken;
      ApiClient.setMockClient(MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/api/devices')) {
          postCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          postedToken = body['deviceToken'] as String?;
          return http.Response(
            jsonEncode({'success': true, 'data': 'Device registered successfully.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }));

      // First registration
      await PushNotificationService.instance.registerDeviceToken('mock-fcm-token-alpha');
      expect(postCount, 1);
      expect(postedToken, 'mock-fcm-token-alpha');

      // Duplicate registration with same token should be ignored
      await PushNotificationService.instance.registerDeviceToken('mock-fcm-token-alpha');
      expect(postCount, 1);

      // New token should be registered
      await PushNotificationService.instance.registerDeviceToken('mock-fcm-token-beta');
      expect(postCount, 2);
      expect(postedToken, 'mock-fcm-token-beta');
    });

    test('unregisterDeviceToken sends DELETE request for registered token', () async {
      await TokenStorage.saveTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-123',
        userId: 'user-123',
      );

      bool deleteReceived = false;
      String? deletedToken;
      ApiClient.setMockClient(MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/api/devices')) {
          return http.Response(
            jsonEncode({'success': true, 'data': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE' && request.url.path.contains('/api/devices/')) {
          deleteReceived = true;
          deletedToken = request.url.pathSegments.last;
          return http.Response(
            jsonEncode({'success': true, 'data': 'Device unregistered successfully.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }));

      // Register first
      await PushNotificationService.instance.registerDeviceToken('mock-token-to-delete');

      // Unregister
      await PushNotificationService.instance.unregisterDeviceToken();

      expect(deleteReceived, isTrue);
      expect(deletedToken, 'mock-token-to-delete');
    });

    test('activeConversationId is tracked accurately', () {
      final service = PushNotificationService.instance;
      expect(service.activeConversationId, isNull);

      service.activeConversationId = 'conv-456';
      expect(service.activeConversationId, 'conv-456');

      service.activeConversationId = null;
      expect(service.activeConversationId, isNull);
    });
  });
}
