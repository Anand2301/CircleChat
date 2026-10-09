import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/push_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/circle_chat_logo.dart';
import 'auth_controller.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkState(ref.read(authProvider));
    });
  }

  void _checkState(AuthState state) {
    if (!mounted) return;
    if (!state.isLoading) {
      if (state.isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PushNotificationService.instance.consumePendingConversation();
        });
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      _checkState(next);
    });

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleChatLogo(size: 96, borderRadius: 26),
            const SizedBox(height: 28),
            const Text(
              'CircleChat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private, invite-only conversations',
              style: TextStyle(
                fontSize: 14.5,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.mintAccent),
            ),
          ],
        ),
      ),
    );
  }
}
