import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _keyTheme = 'circle_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyTheme);
    if (mode == 'light') state = ThemeMode.light;
    if (mode == 'dark') state = ThemeMode.dark;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) await prefs.setString(_keyTheme, 'light');
    if (mode == ThemeMode.dark) await prefs.setString(_keyTheme, 'dark');
    if (mode == ThemeMode.system) await prefs.remove(_keyTheme);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
