import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/api_constants.dart';
import '../models/models.dart';
import '../network/api_client.dart';
import '../network/signalr_service.dart';
import '../storage/token_storage.dart';
import '../../features/chat/chat_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService with WidgetsBindingObserver {
  static PushNotificationService? _instance;
  static PushNotificationService get instance => _instance ??= PushNotificationService._();

  PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;
  String? activeConversationId;
  String? _lastRegisteredToken;
  String? _pendingConversationId;
  bool _isInitialized = false;

  VoidCallback? onSyncActiveConversation;
  VoidCallback? onConversationListRefreshNeeded;

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool get isInForeground => _lifecycleState == AppLifecycleState.resumed;
  String? get pendingConversationId => _pendingConversationId;

  static const String notificationChannelId = 'circle_chat_messages';
  static const String notificationChannelName = 'CircleChat Messages';
  static const String notificationChannelDescription = 'Notifications for direct and group conversations';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isInitialized) {
      _navigatorKey = navigatorKey;
      return;
    }
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);

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
        final convId = initialMessage.data['conversationId']?.toString();
        if (convId != null && convId.isNotEmpty) {
          _pendingConversationId = convId;
        }
      }

      // Check if launched from local notification tap
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          _pendingConversationId = payload;
        }
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

  void consumePendingConversation() {
    final targetId = _pendingConversationId;
    _pendingConversationId = null;
    if (targetId != null && targetId.isNotEmpty) {
      navigateToConversation(targetId);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final convId = data['conversationId']?.toString();

    // Trigger conversation-list refresh if callback registered
    try {
      onConversationListRefreshNeeded?.call();
    } catch (_) {}

    // If viewing this exact conversation, trigger active chat sync and suppress heads-up notification
    if (convId != null &&
        activeConversationId != null &&
        convId.trim().toLowerCase() == activeConversationId!.trim().toLowerCase()) {
      try {
        onSyncActiveConversation?.call();
      } catch (_) {}
      return;
    }

    // If not in foreground, Android native FCM payload handles the notification shade
    if (!isInForeground) return;

    // Determine notification title and body
    final title = message.notification?.title ??
        (data['isGroup'] == 'true' && data['conversationName'] != null
            ? '${data['senderDisplayName'] ?? 'Someone'} in ${data['conversationName']}'
            : (data['senderDisplayName'] ?? 'CircleChat'));

    final body = message.notification?.body ?? data['content'] ?? 'New message';

    // Show native local notification with stable conversation grouping
    final notificationId = convId != null ? (convId.hashCode.abs() % 100000) : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
      tag: convId,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

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

    // Ensure SignalR connection is active or reconnecting when notification opens a conversation
    SignalRService.instance.ensureConnected();

    final targetId = conversationId.trim().toLowerCase();
    // Prevent duplicate navigation if user is already actively viewing this conversation
    if (activeConversationId != null && activeConversationId!.trim().toLowerCase() == targetId) {
      return;
    }

    try {
      // Dismiss active local notification for this conversation
      final notificationId = conversationId.hashCode.abs() % 100000;
      await _localNotifications.cancel(id: notificationId, tag: conversationId);
    } catch (_) {}

    try {
      // Fetch full authoritative conversation model from backend
      final data = await ApiClient.get(ApiConstants.conversationDetails(conversationId));
      final conv = ConversationModel.fromJson(data);

      if (activeConversationId != null && activeConversationId!.trim().toLowerCase() == targetId) {
        return;
      }

      navState.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: conv),
        ),
      );
    } catch (_) {
      // Fallback: minimal valid conversation model
      if (activeConversationId != null && activeConversationId!.trim().toLowerCase() == targetId) {
        return;
      }
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
