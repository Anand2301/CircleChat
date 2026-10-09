import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessToken = 'circle_access_token';
  static const _keyRefreshToken = 'circle_refresh_token';
  static const _keyUserId = 'circle_user_id';
  static const _keyServerUrl = 'circle_server_url';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      await _storage.write(key: _keyUserId, value: userId);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, accessToken);
      await prefs.setString(_keyRefreshToken, refreshToken);
      await prefs.setString(_keyUserId, userId);
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAccessToken);
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    }
  }

  static Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
  }

  static Future<String?> getSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
  }
}
