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
  static final http.Client _client = http.Client();

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
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await _client.get(Uri.parse(url), headers: headers);
    return _handleResponse(response, () => get(url, requiresAuth: requiresAuth));
  }

  static Future<dynamic> post(String url, {dynamic body, bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, () => post(url, body: body, requiresAuth: requiresAuth));
  }

  static Future<dynamic> put(String url, {dynamic body, bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await _client.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, () => put(url, body: body, requiresAuth: requiresAuth));
  }

  static Future<dynamic> delete(String url, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await _client.delete(Uri.parse(url), headers: headers);
    return _handleResponse(response, () => delete(url, requiresAuth: requiresAuth));
  }

  static Future<dynamic> uploadFile(String url, File file, {String fieldName = 'file'}) async {
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

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response, null);
  }

  static Future<dynamic> _handleResponse(
    http.Response response,
    Future<dynamic> Function()? retryCall,
  ) async {
    // Check if token expired and refresh
    if (response.statusCode == 401 && retryCall != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return await retryCall();
      } else {
        await TokenStorage.clear();
        throw ApiException('Session expired. Please log in again.', statusCode: 401);
      }
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic> && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }

    String errorMessage = 'Request failed (${response.statusCode})';
    List<String> errors = [];

    if (body is Map<String, dynamic>) {
      if (body['message'] != null) {
        errorMessage = body['message'].toString();
      }
      if (body['errors'] is List) {
        errors = (body['errors'] as List).map((e) => e.toString()).toList();
      }
    }

    throw ApiException(errorMessage, statusCode: response.statusCode, errors: errors);
  }

  static Future<bool> _tryRefreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.authRefresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;
        final userId = data['user']['id'] as String;

        await TokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          userId: userId,
        );
        return true;
      }
    } catch (_) {}

    return false;
  }
}
