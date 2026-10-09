import 'package:flutter/material.dart';

class AppTheme {
  // iOS / Premium Brand Palette
  static const Color primaryColor = Color(0xFF007AFF); // Apple Blue
  static const Color primaryDark = Color(0xFF0A84FF);  // Apple Dark Blue
  static const Color secondaryColor = Color(0xFF5856D6); // Indigo / Purple
  static const Color emeraldGreen = Color(0xFF34C759); // Apple Online Green
  static const Color errorColor = Color(0xFFFF3B30);   // Apple Red
  static const Color warningColor = Color(0xFFFF9500); // Apple Orange

  // Light Mode Surfaces & Neutrals
  static const Color lightScaffold = Color(0xFFF2F2F7);
  static const Color lightSurface = Colors.white;
  static const Color lightInputFill = Color(0xFFE9E9EB);
  static const Color lightDivider = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF8E8E93);
  static const Color lightBubbleMe = Color(0xFF007AFF);
  static const Color lightBubbleOther = Color(0xFFE9E9EB);

  // Dark Mode Surfaces & Neutrals
  static const Color darkScaffold = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151E32);
  static const Color darkInputFill = Color(0xFF1E293B);
  static const Color darkDivider = Color(0xFF2D3748);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBubbleMe = Color(0xFF2563EB);
  static const Color darkBubbleOther = Color(0xFF1E293B);

  // Avatar Gradients for dynamic, vibrant avatars
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF007AFF), Color(0xFF5856D6)],
    [Color(0xFFFF2D55), Color(0xFFFF375F)],
    [Color(0xFF34C759), Color(0xFF30D158)],
    [Color(0xFFFF9500), Color(0xFFFF9F0A)],
    [Color(0xFFAF52DE), Color(0xFFBF5AF2)],
    [Color(0xFF5AC8FA), Color(0xFF64D2FF)],
    [Color(0xFFFF3B30), Color(0xFFFF453A)],
  ];

  static List<Color> getAvatarGradient(String seed) {
    if (seed.isEmpty) return avatarGradients[0];
    final hash = seed.codeUnits.fold(0, (acc, c) => acc + c);
    return avatarGradients[hash % avatarGradients.length];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: lightSurface,
        surfaceContainerHighest: lightInputFill,
      ),
      scaffoldBackgroundColor: lightScaffold,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: lightSurface,
        foregroundColor: lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightDivider, width: 0.5),
        ),
        color: lightSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: lightTextSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: lightTextSecondary);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        brightness: Brightness.dark,
        primary: primaryDark,
        secondary: secondaryColor,
        error: errorColor,
        surface: darkSurface,
        surfaceContainerHighest: darkInputFill,
      ),
      scaffoldBackgroundColor: darkScaffold,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkDivider, width: 0.5),
        ),
        color: darkSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        indicatorColor: primaryDark.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryDark, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: darkTextSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryDark);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
      ),
    );
  }
}
