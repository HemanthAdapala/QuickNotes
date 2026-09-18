import 'dart:io';
import 'package:flutter/material.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;
  final String heroTag;

  const FullscreenImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffset.dy.abs() > 150.0 || velocity.abs() > 800.0) {
      // Swipe down or up with sufficient distance/velocity triggers dismissal
      Navigator.of(context).pop();
    } else {
      // Snap back to center
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFile = !widget.imagePath.startsWith('http://') &&
        !widget.imagePath.startsWith('https://');
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

    // Calculate background opacity based on drag offset
    final double dragRatio = (_dragOffset.dy.abs() / 300.0).clamp(0.0, 1.0);
    final double bgOpacity = 1.0 - dragRatio;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: Stack(
        children: [
          // Drag-to-dismiss wrapper
          GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: _dragOffset,
              child: Center(
                child: Hero(
                  tag: widget.heroTag,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined,
                                size: 60, color: Colors.white60),
                            SizedBox(height: 12),
                            Text("Error loading image",
                                style: TextStyle(color: Colors.white70)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Close button at top-left
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _dragOffset == Offset.zero ? 1.0 : 0.0,
                child: CircleAvatar(
                  backgroundColor: Colors.black38,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
