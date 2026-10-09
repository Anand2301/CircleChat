import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../theme/app_theme.dart';

/// Resolves any relative or dev URL to an authoritative, accessible URL
String? resolveMediaUrl(String? url) {
  if (url == null) return null;
  final clean = url.trim();
  if (clean.isEmpty) return null;

  // Replace localhost references with current configured base URL
  if (clean.startsWith('http://localhost') ||
      clean.startsWith('https://localhost') ||
      clean.startsWith('http://127.0.0.1') ||
      clean.startsWith('http://10.0.2.2')) {
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      final baseUri = Uri.parse(ApiConstants.baseUrl);
      final replaced = uri.replace(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
      );
      return replaced.toString();
    }
  }

  // Prepend base URL for relative paths
  if (clean.startsWith('/')) {
    return '${ApiConstants.baseUrl}$clean';
  }
  if (clean.startsWith('uploads/') || clean.startsWith('api/')) {
    return '${ApiConstants.baseUrl}/$clean';
  }

  // Return standard HTTP/HTTPS URL
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return clean;
  }

  return clean;
}

String getInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'C';
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return trimmed[0].toUpperCase();
}

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

  Widget _buildInitials(List<Color> gradientColors, String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: (radius * 0.8).clamp(10.0, 36.0),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.getAvatarGradient(name);
    final initials = getInitials(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final resolvedUrl = resolveMediaUrl(imageUrl);

    Widget avatar;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      avatar = _buildInitials(gradientColors, initials);
    } else {
      avatar = ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            resolvedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildInitials(gradientColors, initials);
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildInitials(gradientColors, initials);
            },
          ),
        ),
      );
    }

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
