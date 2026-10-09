import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatar_widget.dart';
import '../authentication/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _displayNameController.text = user.displayName;
      _bioController.text = user.bio ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final data = await ApiClient.put(
        ApiConstants.usersMe,
        body: {
          'displayName': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
        },
      );
      final updatedUser = UserModel.fromJson(data);
      ref.read(authProvider.notifier).updateUserProfile(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isSaving = true);
    try {
      final uploadData = await ApiClient.uploadFile(
        ApiConstants.attachmentsUpload,
        File(picked.path),
      );
      final downloadUrl = uploadData['downloadUrl'] as String;

      final data = await ApiClient.put(
        ApiConstants.usersMe,
        body: {
          'displayName': _displayNameController.text.trim(),
          'bio': _bioController.text.trim(),
          'profileImageUrl': downloadUrl,
        },
      );
      final updatedUser = UserModel.fromJson(data);
      ref.read(authProvider.notifier).updateUserProfile(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload avatar: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final curController = TextEditingController();
    final newController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: curController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (min 8 chars)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiClient.post(
                  ApiConstants.authChangePassword,
                  body: {
                    'currentPassword': curController.text,
                    'newPassword': newController.text,
                  },
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                      backgroundColor: AppTheme.emeraldGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
      appBar: AppBar(
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            )
          else
            TextButton(
              onPressed: _handleSave,
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Avatar Header
            Center(
              child: Stack(
                children: [
                  CircleAvatarWithStatus(
                    name: user?.displayName ?? 'User',
                    imageUrl: user?.profileImageUrl,
                    radius: 50,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _handlePickAvatar,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user?.fullName ?? '',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user?.email ?? '',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            // Profile Info Group
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'PROFILE INFO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio / Status',
                      prefixIcon: Icon(Icons.info_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Security Group
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'SECURITY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  width: 0.5,
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor, size: 20),
                ),
                title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 22),
                onTap: _showChangePasswordDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
