import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String fileName;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.fileName = 'Image',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                  color: AppTheme.mintAccent,
                  strokeWidth: 2.5,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_rounded, size: 64, color: AppTheme.secondaryText),
                  SizedBox(height: 12),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: AppTheme.secondaryText, fontSize: 15),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
