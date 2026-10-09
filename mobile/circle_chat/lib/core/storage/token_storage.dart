import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static final Map<String, String> _inMemoryFallback = {};

  static const _keyAccessToken = 'circle_access_token';
  static const _keyRefreshToken = 'circle_refresh_token';
  static const _keyUserId = 'circle_user_id';
  static const _keyServerUrl = 'circle_server_url';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    _inMemoryFallback[_keyAccessToken] = accessToken;
    _inMemoryFallback[_keyRefreshToken] = refreshToken;
    _inMemoryFallback[_keyUserId] = userId;

    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      await _storage.write(key: _keyUserId, value: userId);
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAccessToken, accessToken);
        await prefs.setString(_keyRefreshToken, refreshToken);
        await prefs.setString(_keyUserId, userId);
      } catch (_) {}
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_keyAccessToken);
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
    }
    return _inMemoryFallback[_keyAccessToken];
  }

  static Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_keyRefreshToken);
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {}
    }
    return _inMemoryFallback[_keyRefreshToken];
  }

  static Future<String?> getUserId() async {
    try {
      final id = await _storage.read(key: _keyUserId);
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final id = prefs.getString(_keyUserId);
        if (id != null && id.isNotEmpty) return id;
      } catch (_) {}
    }
    return _inMemoryFallback[_keyUserId];
  }

  static Future<void> clear() async {
    _inMemoryFallback.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUserId);
    } catch (_) {}
  }

  static Future<String?> getSavedServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyServerUrl);
    } catch (_) {
      return _inMemoryFallback[_keyServerUrl];
    }
  }

  static Future<void> saveServerUrl(String url) async {
    _inMemoryFallback[_keyServerUrl] = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyServerUrl, url);
    } catch (_) {}
  }
}
