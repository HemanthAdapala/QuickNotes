import 'dart:io';
import 'package:flutter/material.dart';

class NewImageWidget extends StatelessWidget {
  final String imagePath;
  final double? width;
  final String? caption;

  const NewImageWidget({
    super.key,
    required this.imagePath,
    this.width,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFile = !imagePath.startsWith('http://') && !imagePath.startsWith('https://');

    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = (screenWidth - 48.0).clamp(100.0, 720.0);
    final double currentWidth = (width ?? maxWidth).clamp(150.0, maxWidth);

    ImageProvider imageProvider;
    if (isFile) {
      String cleanPath = imagePath;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
      }
      if (cleanPath.startsWith('/') && cleanPath.length > 2 && cleanPath[2] == ':') {
        cleanPath = cleanPath.substring(1);
      }
      imageProvider = FileImage(File(cleanPath));
    } else {
      imageProvider = NetworkImage(imagePath);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            width: currentWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.08), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image(
                image: imageProvider,
                width: currentWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: currentWidth,
                    height: 150,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          "Error loading image",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, top: 4.0, bottom: 8.0),
              child: Text(
                caption!.startsWith('📍') ? caption! : '📍 $caption',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
