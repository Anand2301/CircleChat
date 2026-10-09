import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../authentication/auth_controller.dart';
import '../authentication/login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showServerUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConstants.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Backend Server URL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default production endpoint: https://circlechat-49kc.onrender.com\nYou can customize this for staging or local testing if needed.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Backend Base URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              ApiConstants.baseUrl = controller.text.trim();
              await TokenStorage.saveServerUrl(controller.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Updated backend URL to: ${ApiConstants.baseUrl}'),
                    backgroundColor: AppTheme.emeraldGreen,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildSectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      );
    }

    Widget buildCard(List<Widget> children) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            width: 0.5,
          ),
        ),
        child: Column(children: children),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // APPEARANCE
          buildSectionHeader('APPEARANCE'),
          buildCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.brightness_6_rounded, color: AppTheme.primaryColor, size: 20),
              ),
              title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                themeMode == ThemeMode.light
                    ? 'Light'
                    : (themeMode == ThemeMode.dark ? 'Dark' : 'System Default'),
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setTheme(mode);
                  }
                },
              ),
            ),
          ]),

          // NETWORK & SERVER
          buildSectionHeader('NETWORK & SERVER'),
          buildCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.dns_rounded, color: Color(0xFF5856D6), size: 20),
              ),
              title: const Text('Backend API Server', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                ApiConstants.baseUrl,
                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _showServerUrlDialog(context),
            ),
          ]),

          // PRIVACY & ABOUT
          buildSectionHeader('PRIVACY & ABOUT'),
          buildCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppTheme.emeraldGreen, size: 20),
              ),
              title: const Text('Security Architecture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                'Invite-only perimeter with token rotation & HTTPS',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
            Divider(height: 1, indent: 56, color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.blueGrey, size: 20),
              ),
              title: const Text('CircleChat Version', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                'v1.0.0 (Production Release)',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ]),

          // ACCOUNT
          buildSectionHeader('ACCOUNT'),
          buildCard([
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 20),
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.errorColor),
              ),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ]),
        ],
      ),
    );
  }
}
