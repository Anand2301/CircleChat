import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String> errors;

  ApiException(this.message, {this.statusCode = 400, this.errors = const []});

  @override
  String toString() => message;
}

class ApiClient {
  static final http.Client _defaultClient = http.Client();
  static http.Client? _mockClient;

  /// Allows setting a mock http.Client for automated unit and integration tests.
  static void setMockClient(http.Client? client) {
    _mockClient = client;
  }

  static http.Client get _activeClient => _mockClient ?? _defaultClient;
  static const Duration _timeoutDuration = Duration(seconds: 30);

  /// Generates request headers, attaching Authorization Bearer token ONLY when requiresAuth is true.
  static Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await TokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> get(String url, {bool requiresAuth = true}) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _activeClient
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeoutDuration);
      return await _handleResponse(
        response,
        requiresAuth ? () => get(url, requiresAuth: true) : null,
        requiresAuth: requiresAuth,
      );
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: 503,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be waking up, please try again.',
        statusCode: 408,
      );
    }
  }

  static Future<dynamic> post(
    String url, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _activeClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeoutDuration);
      return await _handleResponse(
        response,
        requiresAuth ? () => post(url, body: body, requiresAuth: true) : null,
        requiresAuth: requiresAuth,
      );
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: 503,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be waking up, please try again.',
        statusCode: 408,
      );
    }
  }

  static Future<dynamic> put(
    String url, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _activeClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeoutDuration);
      return await _handleResponse(
        response,
        requiresAuth ? () => put(url, body: body, requiresAuth: true) : null,
        requiresAuth: requiresAuth,
      );
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: 503,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be waking up, please try again.',
        statusCode: 408,
      );
    }
  }

  static Future<dynamic> delete(String url, {bool requiresAuth = true}) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _activeClient
          .delete(Uri.parse(url), headers: headers)
          .timeout(_timeoutDuration);
      return await _handleResponse(
        response,
        requiresAuth ? () => delete(url, requiresAuth: true) : null,
        requiresAuth: requiresAuth,
      );
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: 503,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be waking up, please try again.',
        statusCode: 408,
      );
    }
  }

  static Future<dynamic> uploadFile(
    String url,
    File file, {
    String fieldName = 'file',
  }) async {
    try {
      final token = await TokenStorage.getAccessToken();
      final request = http.MultipartRequest('POST', Uri.parse(url));

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final ext = file.path.split('.').last.toLowerCase();
      String mimeType = 'application/octet-stream';
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'pdf') mimeType = 'application/pdf';

      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

      final streamedResponse = await _activeClient.send(request).timeout(_timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);
      return await _handleResponse(response, null, requiresAuth: true);
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Network error: ${e.message}',
        statusCode: 503,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out. The server may be waking up, please try again.',
        statusCode: 408,
      );
    }
  }

  static Future<dynamic> _handleResponse(
    http.Response response,
    Future<dynamic> Function()? retryCall, {
    bool requiresAuth = true,
  }) async {
    // 1. Handle 401 Unauthorized
    if (response.statusCode == 401) {
      // If the request was protected and we have a retry callback, attempt token refresh
      if (requiresAuth && retryCall != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          return await retryCall();
        } else {
          await TokenStorage.clear();
          throw ApiException('Session expired. Please log in again.', statusCode: 401);
        }
      }

      // If unauthenticated endpoint (e.g. login), return user-friendly invalid credentials message
      throw ApiException(
        'Invalid email or password. Please check your credentials.',
        statusCode: 401,
      );
    }

    // 2. Parse JSON response body
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    // 3. Handle successful 2xx responses
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic> && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }

    // 4. Extract error details from body
    String errorMessage = 'Request failed (${response.statusCode})';
    List<String> errors = [];

    if (body is Map<String, dynamic>) {
      if (body['message'] != null && body['message'].toString().trim().isNotEmpty) {
        errorMessage = body['message'].toString();
      }

      if (body['errors'] is List) {
        errors = (body['errors'] as List).map((e) => e.toString()).toList();
      } else if (body['errors'] is Map) {
        for (final entry in (body['errors'] as Map).entries) {
          final val = entry.value;
          if (val is List) {
            errors.addAll(val.map((e) => e.toString()));
          } else if (val != null) {
            errors.add(val.toString());
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      if (errorMessage.isEmpty || errorMessage.contains('One or more errors')) {
        errorMessage = errors.join('\n');
      }
    }

    if (response.statusCode >= 500) {
      errorMessage = 'Server error (${response.statusCode}). Please try again later.';
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      errors: errors,
    );
  }

  static Future<bool> _tryRefreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _activeClient
          .post(
            Uri.parse(ApiConstants.authRefresh),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json is Map<String, dynamic> ? json['data'] : null;
        if (data != null && data is Map<String, dynamic>) {
          final newAccessToken = data['accessToken'] as String? ?? '';
          final newRefreshToken = data['refreshToken'] as String? ?? '';
          final user = data['user'];
          final userId = (user is Map<String, dynamic> ? user['id'] : null) as String? ?? '';

          if (newAccessToken.isNotEmpty) {
            await TokenStorage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
              userId: userId,
            );
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }
}
