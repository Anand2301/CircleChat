import 'package:flutter/material.dart';

class AppTheme {
  // Cozy Brand Palette
  static const Color midnightBackground = Color(0xFF101820);
  static const Color elevatedSurface = Color(0xFF19252D);
  static const Color mintAccent = Color(0xFFB7F7D4);
  static const Color paleBlue = Color(0xFFA5D8F3);
  static const Color warmCream = Color(0xFFE9E1D5);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF84949C);
  static const Color dividerColor = Color(0xFF22323D);
  static const Color inputFillColor = Color(0xFF152028);

  // Brand Accent Aliases
  static const Color primaryColor = Color(0xFFB7F7D4); // Mint Accent
  static const Color primaryDark = Color(0xFFB7F7D4);
  static const Color secondaryColor = Color(0xFFA5D8F3); // Pale Blue
  static const Color emeraldGreen = Color(0xFFB7F7D4);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB74D);

  // Surfaces & Bubbles
  static const Color lightScaffold = Color(0xFF101820);
  static const Color lightSurface = Color(0xFF19252D);
  static const Color lightInputFill = Color(0xFF152028);
  static const Color lightDivider = Color(0xFF22323D);
  static const Color lightTextPrimary = Color(0xFFFFFFFF);
  static const Color lightTextSecondary = Color(0xFF84949C);
  static const Color lightBubbleMe = Color(0xFFB7F7D4);
  static const Color lightBubbleOther = Color(0xFF19252D);

  static const Color darkScaffold = Color(0xFF101820);
  static const Color darkSurface = Color(0xFF19252D);
  static const Color darkInputFill = Color(0xFF152028);
  static const Color darkDivider = Color(0xFF22323D);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF84949C);
  static const Color darkBubbleMe = Color(0xFFB7F7D4);
  static const Color darkBubbleOther = Color(0xFF19252D);

  // Avatar Gradients for dynamic, vibrant avatars
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFB7F7D4), Color(0xFFA5D8F3)],
    [Color(0xFFA5D8F3), Color(0xFF70A9D4)],
    [Color(0xFFE9E1D5), Color(0xFFB7F7D4)],
    [Color(0xFF81D4FA), Color(0xFF4FC3F7)],
    [Color(0xFF80CBC4), Color(0xFF4DB6AC)],
    [Color(0xFFA7FFEB), Color(0xFF64FFDA)],
    [Color(0xFFB2DFDB), Color(0xFF80CBC4)],
  ];

  static List<Color> getAvatarGradient(String seed) {
    if (seed.isEmpty) return avatarGradients[0];
    final hash = seed.codeUnits.fold(0, (acc, c) => acc + c);
    return avatarGradients[hash % avatarGradients.length];
  }

  static ThemeData get lightTheme => darkTheme; // Default to cozy dark experience

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: mintAccent,
        onPrimary: midnightBackground,
        secondary: paleBlue,
        onSecondary: midnightBackground,
        error: errorColor,
        onError: Colors.white,
        surface: elevatedSurface,
        onSurface: primaryText,
        surfaceContainerHighest: inputFillColor,
      ),
      scaffoldBackgroundColor: midnightBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: elevatedSurface,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor, width: 0.8),
        ),
        color: elevatedSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.8,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: mintAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: secondaryText, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: mintAccent,
          foregroundColor: midnightBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: elevatedSurface,
        elevation: 0,
        indicatorColor: mintAccent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: mintAccent, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: secondaryText, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: mintAccent);
          }
          return const IconThemeData(color: secondaryText);
        }),
      ),
    );
  }
}
