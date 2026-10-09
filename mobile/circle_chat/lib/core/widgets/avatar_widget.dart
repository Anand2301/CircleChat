import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CircleAvatarWithStatus extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isOnline;
  final double radius;
  final bool showStatus;
  final VoidCallback? onTap;

  const CircleAvatarWithStatus({
    super.key,
    this.imageUrl,
    required this.name,
    this.isOnline = false,
    this.radius = 24,
    this.showStatus = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.getAvatarGradient(name);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkSurface : Colors.white;

    Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: imageUrl == null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.85,
                letterSpacing: -0.5,
              ),
            )
          : null,
    );

    if (showStatus && isOnline) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: (radius * 0.55).clamp(10.0, 14.0),
              height: (radius * 0.55).clamp(10.0, 14.0),
              decoration: BoxDecoration(
                color: AppTheme.emeraldGreen,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
