import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:circle_chat/core/constants/api_constants.dart';
import 'package:circle_chat/core/network/api_client.dart';
import 'package:circle_chat/core/storage/token_storage.dart';
import 'package:circle_chat/features/authentication/auth_controller.dart';

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

  group('ApiConstants Configuration Tests', () {
    test('Default production base URL is configured centrally to Render endpoint', () {
      expect(ApiConstants.defaultBaseUrl, 'https://circlechat-49kc.onrender.com');
      expect(ApiConstants.baseUrl, 'https://circlechat-49kc.onrender.com');
      expect(ApiConstants.authLogin, 'https://circlechat-49kc.onrender.com/api/auth/login');
      expect(ApiConstants.authRegister, 'https://circlechat-49kc.onrender.com/api/auth/register');
      expect(ApiConstants.authRefresh, 'https://circlechat-49kc.onrender.com/api/auth/refresh');
      expect(ApiConstants.usersMe, 'https://circlechat-49kc.onrender.com/api/users/me');
    });
  });

  group('TokenStorage Persistence Tests', () {
    test('Stores and retrieves access token, refresh token, and user ID securely', () async {
      await TokenStorage.saveTokens(
        accessToken: 'mock_jwt_access_token_123',
        refreshToken: 'mock_refresh_token_456',
        userId: 'user_guid_789',
      );

      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();
      final userId = await TokenStorage.getUserId();

      expect(accessToken, 'mock_jwt_access_token_123');
      expect(refreshToken, 'mock_refresh_token_456');
      expect(userId, 'user_guid_789');

      await TokenStorage.clear();
      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
      expect(await TokenStorage.getUserId(), isNull);
    });
  });

  group('ApiClient Authentication & Error Handling Tests', () {
    test('Login success parses response and does not send Authorization header', () async {
      String? authHeaderReceived;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          authHeaderReceived = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'success': true,
              'statusCode': 200,
              'message': 'Login successful.',
              'data': {
                'accessToken': 'valid_jwt_token',
                'refreshToken': 'valid_refresh_token',
                'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
                'user': {
                  'id': 'founder-id-123',
                  'email': 'founder@circlechat.test',
                  'fullName': 'Founder User',
                  'displayName': 'Founder',
                  'bio': 'System Founder',
                  'profileImageUrl': null,
                  'isOnline': true,
                  'createdAt': DateTime.now().toIso8601String(),
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final data = await ApiClient.post(
        ApiConstants.authLogin,
        body: {'email': 'founder@circlechat.test', 'password': 'Password123!'},
        requiresAuth: false,
      );

      expect(authHeaderReceived, isNull, reason: 'Unauthenticated requests must not attach Bearer token');
      expect(data, isNotNull);
      expect(data['accessToken'], 'valid_jwt_token');
      expect(data['refreshToken'], 'valid_refresh_token');
      expect(data['user']['email'], 'founder@circlechat.test');
    });

    test('Login failure with invalid credentials returns 401 with friendly error message', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      expect(
        () => ApiClient.post(
          ApiConstants.authLogin,
          body: {'email': 'wrong@example.com', 'password': 'badpassword'},
          requiresAuth: false,
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Invalid email or password'),
        )),
      );
    });

    test('Register failure with invalid invitation code extracts backend error message', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/register') {
          return http.Response(
            jsonEncode({
              'success': false,
              'statusCode': 400,
              'message': 'Invalid, inactive, or expired invitation code.',
              'errors': null,
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      expect(
        () => ApiClient.post(
          ApiConstants.authRegister,
          body: {
            'invitationCode': 'CC-INVALID123',
            'fullName': 'Alice Smith',
            'displayName': 'Alice',
            'email': 'alice@example.com',
            'password': 'Password123!',
            'confirmPassword': 'Password123!',
          },
          requiresAuth: false,
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Invalid, inactive, or expired invitation code'),
        )),
      );
    });

    test('Register failure with FastEndpoints validation dictionary extracts field errors', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/register') {
          return http.Response(
            jsonEncode({
              'statusCode': 400,
              'message': 'One or more errors occurred!',
              'errors': {
                'password': ['Password must be at least 6 characters.'],
                'confirmPassword': ['Passwords do not match.'],
              },
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      try {
        await ApiClient.post(
          ApiConstants.authRegister,
          body: {
            'invitationCode': 'CC-FOUNDER2026',
            'fullName': 'Bob',
            'displayName': 'Bob',
            'email': 'bob@example.com',
            'password': '123',
            'confirmPassword': '456',
          },
          requiresAuth: false,
        );
        fail('Expected ApiException to be thrown');
      } on ApiException catch (e) {
        expect(e.errors, contains('Password must be at least 6 characters.'));
        expect(e.errors, contains('Passwords do not match.'));
        expect(e.message, contains('Password must be at least 6 characters.'));
      }
    });

    test('Protected API request attaches Authorization: Bearer <access_token>', () async {
      await TokenStorage.saveTokens(
        accessToken: 'secret_jwt_access_token_xyz',
        refreshToken: 'refresh_token_123',
        userId: 'user_1',
      );

      String? attachedAuthHeader;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/users/me') {
          attachedAuthHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'success': true,
              'statusCode': 200,
              'data': {
                'id': 'user_1',
                'email': 'founder@circlechat.test',
                'fullName': 'Founder User',
                'displayName': 'Founder',
                'isOnline': true,
                'createdAt': DateTime.now().toIso8601String(),
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final data = await ApiClient.get(ApiConstants.usersMe, requiresAuth: true);
      expect(attachedAuthHeader, 'Bearer secret_jwt_access_token_xyz');
      expect(data['email'], 'founder@circlechat.test');
    });

    test('Protected request triggers automatic token refresh on 401 and retries original request', () async {
      await TokenStorage.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'valid_refresh_token_abc',
        userId: 'user_1',
      );

      int usersMeCalls = 0;
      bool refreshCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/users/me') {
          usersMeCalls++;
          final auth = request.headers['Authorization'];
          if (auth == 'Bearer expired_access_token') {
            return http.Response('{"statusCode":401}', 401);
          } else if (auth == 'Bearer new_fresh_access_token') {
            return http.Response(
              jsonEncode({
                'success': true,
                'statusCode': 200,
                'data': {
                  'id': 'user_1',
                  'email': 'refreshed@circlechat.test',
                  'fullName': 'Refreshed User',
                  'displayName': 'Refreshed',
                  'isOnline': true,
                  'createdAt': DateTime.now().toIso8601String(),
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        } else if (request.url.path == '/api/auth/refresh') {
          refreshCalled = true;
          final body = jsonDecode(request.body);
          if (body['refreshToken'] == 'valid_refresh_token_abc') {
            return http.Response(
              jsonEncode({
                'success': true,
                'statusCode': 200,
                'message': 'Token refreshed.',
                'data': {
                  'accessToken': 'new_fresh_access_token',
                  'refreshToken': 'new_fresh_refresh_token',
                  'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
                  'user': {'id': 'user_1'}
                }
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final data = await ApiClient.get(ApiConstants.usersMe, requiresAuth: true);

      expect(refreshCalled, isTrue, reason: 'Refresh endpoint must be called upon 401');
      expect(usersMeCalls, 2, reason: 'Request should have been tried once, then retried with new token');
      expect(data['email'], 'refreshed@circlechat.test');

      // Verify that new tokens were saved to TokenStorage
      expect(await TokenStorage.getAccessToken(), 'new_fresh_access_token');
      expect(await TokenStorage.getRefreshToken(), 'new_fresh_refresh_token');
    });

    test('Server error 500 throws friendly server error message', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      ApiClient.setMockClient(mockClient);

      expect(
        () => ApiClient.get(ApiConstants.usersMe, requiresAuth: true),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Server error (500)'),
        )),
      );
    });
  });

  group('AuthNotifier State Controller Integration Tests', () {
    test('login() updates AuthState to authenticated and saves tokens on success', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'success': true,
              'statusCode': 200,
              'data': {
                'accessToken': 'founder_jwt_token',
                'refreshToken': 'founder_refresh_token',
                'expiresAt': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
                'user': {
                  'id': 'founder_id',
                  'email': 'founder@circlechat.test',
                  'fullName': 'Founder User',
                  'displayName': 'Founder',
                  'bio': null,
                  'profileImageUrl': null,
                  'isOnline': true,
                  'createdAt': DateTime.now().toIso8601String(),
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final notifier = AuthNotifier();
      // Wait for initial checkAuth
      await Future.delayed(const Duration(milliseconds: 50));

      final success = await notifier.login('founder@circlechat.test', 'SecurePassword123!');
      expect(success, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user?.email, 'founder@circlechat.test');
      expect(notifier.state.errorMessage, isNull);

      expect(await TokenStorage.getAccessToken(), 'founder_jwt_token');
    });

    test('login() sets errorMessage and remains unauthenticated on invalid credentials', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response('Unauthorized', 401);
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final notifier = AuthNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      final success = await notifier.login('wrong@circlechat.test', 'BadPassword');
      expect(success, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('Invalid email or password'));
    });

    test('register() sets errorMessage when invitation is invalid', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/register') {
          return http.Response(
            jsonEncode({
              'success': false,
              'statusCode': 400,
              'message': 'Invalid, inactive, or expired invitation code.',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final notifier = AuthNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      final success = await notifier.register(
        invitationCode: 'CC-EXPIRED',
        fullName: 'New User',
        displayName: 'New',
        email: 'new@circlechat.test',
        password: 'Password123!',
        confirmPassword: 'Password123!',
      );

      expect(success, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('Invalid, inactive, or expired invitation code'));
    });

    test('logout() clears tokens and sets isAuthenticated to false', () async {
      await TokenStorage.saveTokens(
        accessToken: 'access_to_clear',
        refreshToken: 'refresh_to_clear',
        userId: 'user_to_clear',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/auth/logout') {
          return http.Response(
            jsonEncode({'success': true, 'statusCode': 200, 'message': 'Logged out.'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      ApiClient.setMockClient(mockClient);

      final notifier = AuthNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      await notifier.logout();

      expect(notifier.state.isAuthenticated, isFalse);
      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
    });
  });
}
