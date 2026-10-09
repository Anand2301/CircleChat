import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/api_constants.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authentication/splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configured backend server URL if custom
  final savedUrl = await TokenStorage.getSavedServerUrl();
  if (savedUrl != null && savedUrl.isNotEmpty) {
    ApiConstants.baseUrl = savedUrl;
  }

  // Initialize Firebase (safely)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) {
      final userToken = await TokenStorage.getAccessToken();
      if (userToken != null) {
        try {
          await ApiClient.post(ApiConstants.devices, body: {
            'deviceToken': token,
            'platform': 0, // Android
          });
        } catch (_) {}
      }
    }
  } catch (_) {
    // If running on an emulator without Google Play Services or during unit test runs
  }

  runApp(const ProviderScope(child: CircleChatApp()));
}

class CircleChatApp extends ConsumerWidget {
  const CircleChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'CircleChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
