import 'dart:io';
import 'package:flutter/material.dart';

class NewImageWidget extends StatefulWidget {
  final String imagePath;
  final double? width;
  final String? caption;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<double> onResize;
  final VoidCallback onDelete;

  const NewImageWidget({
    super.key,
    required this.imagePath,
    this.width,
    this.caption,
    this.isSelected = false,
    required this.onTap,
    required this.onResize,
    required this.onDelete,
  });

  @override
  State<NewImageWidget> createState() => _NewImageWidgetState();
}

class _NewImageWidgetState extends State<NewImageWidget> {
  bool _showSlider = false;

  @override
  void didUpdateWidget(covariant NewImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected) {
      _showSlider = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFile = !widget.imagePath.startsWith('http://') &&
        !widget.imagePath.startsWith('https://');

    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = (screenWidth - 48.0).clamp(100.0, 720.0);
    final double currentWidth =
        (widget.width ?? maxWidth).clamp(150.0, maxWidth);

    ImageProvider imageProvider;
    if (isFile) {
      String cleanPath = widget.imagePath;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
      }
      if (cleanPath.startsWith('/') &&
          cleanPath.length > 2 &&
          cleanPath[2] == ':') {
        cleanPath = cleanPath.substring(1);
      }
      imageProvider = FileImage(File(cleanPath));
    } else {
      imageProvider = NetworkImage(widget.imagePath);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              width: currentWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected
                      ? theme.primaryColor
                      : Colors.black.withOpacity(0.08),
                  width: widget.isSelected ? 2.5 : 1.0,
                ),
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
                          Icon(Icons.broken_image_outlined,
                              size: 40, color: Colors.grey),
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
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, top: 4.0, bottom: 8.0),
              child: Text(
                widget.caption!.startsWith('📍')
                    ? widget.caption!
                    : '📍 ${widget.caption}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          if (widget.isSelected) ...[
            const SizedBox(height: 8.0),
            _buildActionPanel(maxWidth, currentWidth),
          ],
        ],
      ),
    );
  }

  Widget _buildActionPanel(double maxWidth, double currentWidth) {
    final theme = Theme.of(context);

    if (_showSlider) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () {
                setState(() {
                  _showSlider = false;
                });
              },
            ),
            SizedBox(
              width: 110.0,
              child: Slider(
                value: currentWidth,
                min: 150.0,
                max: maxWidth,
                activeColor: theme.primaryColor,
                inactiveColor: theme.disabledColor,
                onChanged: widget.onResize,
              ),
            ),
            Text(
              "${currentWidth.toInt()}px",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(Icons.photo_size_select_large_outlined, "Resize",
              () {
            setState(() {
              _showSlider = true;
            });
          }),
          _buildActionDivider(),
          _buildActionButton(Icons.delete_outline, "Delete", widget.onDelete,
              color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String tooltip, VoidCallback onPressed,
      {Color? color}) {
    final theme = Theme.of(context);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon,
          size: 20,
          color: color ?? theme.colorScheme.onSurface.withOpacity(0.7)),
    );
  }

  Widget _buildActionDivider() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      width: 1.0,
      height: 16.0,
      color: theme.dividerColor,
    );
  }
}
