import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/api_constants.dart';
import '../models/models.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import '../../features/chat/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();

  PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  String? activeConversationId;
  String? _lastRegisteredToken;
  bool _isInitialized = false;

  static const String notificationChannelId = 'circle_chat_messages';
  static const String notificationChannelName = 'CircleChat Messages';
  static const String notificationChannelDescription = 'Notifications for direct and group conversations';

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) {
      _navigatorKey = navigatorKey;
      return;
    }
    _navigatorKey = navigatorKey;

    try {
      // 1. Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            navigateToConversation(payload);
          }
        },
      );

      // 2. Create high-importance Android Notification Channel
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          notificationChannelId,
          notificationChannelName,
          description: notificationChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);

        // Request notification permissions for Android 13+
        await androidImplementation.requestNotificationsPermission();
      }

      // 3. Request Firebase Messaging permissions
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // 4. Configure foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // 6. Handle notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationMessage(message);
      });

      // 7. Check for initial notification message on app launch from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        // Delay slightly to allow the initial navigation route to stabilize
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleNotificationMessage(initialMessage);
        });
      }

      // 8. Listen for token refresh events
      messaging.onTokenRefresh.listen((newToken) {
        registerDeviceToken(newToken);
      });

      _isInitialized = true;
    } catch (_) {
      // Graceful fallback if running without Play Services or in unit tests
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final convId = data['conversationId']?.toString();

    // If the recipient is actively viewing this exact conversation, do not show a banner
    if (convId != null &&
        activeConversationId != null &&
        convId.trim().toLowerCase() == activeConversationId!.trim().toLowerCase()) {
      return;
    }

    // Determine notification title and body
    final title = message.notification?.title ??
        (data['isGroup'] == 'true' && data['conversationName'] != null
            ? '${data['senderDisplayName'] ?? 'Someone'} in ${data['conversationName']}'
            : (data['senderDisplayName'] ?? 'CircleChat'));

    final body = message.notification?.body ?? data['content'] ?? 'New message';

    // Show native local notification
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true, // Displays native arrival time in Android notification shade
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: convId,
    );
  }

  void _handleNotificationMessage(RemoteMessage message) {
    final convId = message.data['conversationId']?.toString();
    if (convId != null && convId.isNotEmpty) {
      navigateToConversation(convId);
    }
  }

  Future<void> navigateToConversation(String conversationId) async {
    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    try {
      // Fetch full conversation model from backend
      final data = await ApiClient.get(ApiConstants.conversationDetails(conversationId));
      final conv = ConversationModel.fromJson(data);

      navState.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv),
        ),
      );
    } catch (_) {
      // If fetching fails, create minimal fallback conversation model
      final fallbackConv = ConversationModel(
        id: conversationId,
        type: 0,
        name: 'Chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: [],
      );

      navState.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: fallbackConv),
        ),
      );
    }
  }

  Future<void> registerDeviceToken([String? token]) async {
    try {
      final userToken = await TokenStorage.getAccessToken();
      if (userToken == null || userToken.isEmpty) return;

      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      // Avoid re-registering the exact same token redundantly
      if (fcmToken == _lastRegisteredToken) return;

      await ApiClient.post(ApiConstants.devices, body: {
        'deviceToken': fcmToken,
        'platform': 0, // Android
      });

      _lastRegisteredToken = fcmToken;
    } catch (_) {
      // Ignore network errors during background token registration
    }
  }

  Future<void> unregisterDeviceToken() async {
    try {
      final token = _lastRegisteredToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiClient.delete('${ApiConstants.devices}/$token');
      }
    } catch (_) {
    } finally {
      _lastRegisteredToken = null;
    }
  }
}
