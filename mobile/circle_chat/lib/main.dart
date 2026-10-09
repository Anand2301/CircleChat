import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/api_constants.dart';
import 'core/network/push_notification_service.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/splash_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configured backend server URL if custom (ignoring old local dev defaults)
  final savedUrl = await TokenStorage.getSavedServerUrl();
  if (savedUrl != null &&
      savedUrl.isNotEmpty &&
      !savedUrl.contains('10.0.2.2') &&
      !savedUrl.contains('localhost')) {
    ApiConstants.baseUrl = savedUrl;
  } else {
    ApiConstants.resetToDefault();
  }

  // Initialize Firebase and Push Notification Service
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize(rootNavigatorKey);
  } catch (_) {
    // Fallback if running on an emulator without Google Play Services or during unit test runs
  }

  runApp(const ProviderScope(child: CircleChatApp()));
}

class CircleChatApp extends ConsumerWidget {
  const CircleChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'CircleChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
