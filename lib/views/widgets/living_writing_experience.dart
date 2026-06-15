import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Represents an active character settling animation.
class CharacterAnimation {
  final int id;
  int startIndex;
  final String char;
  final DateTime startTime;
  final double durationMs;

  CharacterAnimation({
    required this.id,
    required this.startIndex,
    required this.char,
    required this.startTime,
    this.durationMs = 100.0, // 80 - 120ms
  });
}

/// Renders a single character that is settling into place.
class AnimatedCharacterWidget extends StatelessWidget {
  final String char;
  final TextStyle style;
  final double progress;

  const AnimatedCharacterWidget({
    super.key,
    required this.char,
    required this.style,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Smooth easeOutCubic curve
    final double easedProgress = Curves.easeOutCubic.transform(progress);

    // Easing specs:
    // 1. Opacity: 30% -> 100%
    final double opacity = 0.3 + (0.7 * easedProgress);

    // 2. Vertical position: 1.5px down -> 0px (baseline)
    final double translateY = 1.5 * (1.0 - easedProgress);

    // 3. Scale: 0.95 -> 1.0 (ink spreading look)
    final double scale = 0.95 + (0.05 * easedProgress);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Text(
            char,
            style: style,
          ),
        ),
      ),
    );
  }
}

/// A custom editing controller that animates text and headings.
class LivingTextEditingController extends TextEditingController {
  final List<CharacterAnimation> _animations = [];
  final Map<int, DateTime> _headingAnimations = {};
  
  Ticker? _ticker;
  int _nextAnimId = 0;
  String _previousText = "";

  LivingTextEditingController({super.text}) {
    _previousText = text;
    addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _stopTicker();
    removeListener(_onTextChanged);
    super.dispose();
  }

  void _startTicker() {
    if (_ticker == null) {
      _ticker = Ticker((elapsed) {
        _onTick();
      });
      _ticker!.start();
    }
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick() {
    final now = DateTime.now();
    bool hasChanges = false;

    // Update character animations
    _animations.removeWhere((anim) {
      final elapsed = now.difference(anim.startTime).inMilliseconds;
      if (elapsed >= anim.durationMs) {
        hasChanges = true;
        return true;
      }
      return false;
    });

    // Update heading animations
    _headingAnimations.removeWhere((offset, startTime) {
      final elapsed = now.difference(startTime).inMilliseconds;
      if (elapsed >= 300.0) {
        hasChanges = true;
        return true;
      }
      return false;
    });

    if (_animations.isNotEmpty || _headingAnimations.isNotEmpty || hasChanges) {
      notifyListeners();
    }

    if (_animations.isEmpty && _headingAnimations.isEmpty) {
      _stopTicker();
    }
  }

  void _onTextChanged() {
    final newText = text;
    if (newText == _previousText) return;

    _shiftHeadingAnimations(_previousText, newText);
    _updateAnimationIndices(_previousText, newText);
    _updateHeadingAnimations(_previousText, newText);

    _previousText = newText;
  }

  void _shiftHeadingAnimations(String oldText, String newText) {
    int prefixLen = 0;
    while (prefixLen < oldText.length &&
        prefixLen < newText.length &&
        oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    final int addedCount = newText.length - oldText.length;
    if (addedCount == 0) return;

    final newHeadingAnims = <int, DateTime>{};
    _headingAnimations.forEach((offset, startTime) {
      if (offset >= prefixLen) {
        newHeadingAnims[offset + addedCount] = startTime;
      } else {
        newHeadingAnims[offset] = startTime;
      }
    });
    _headingAnimations.clear();
    _headingAnimations.addAll(newHeadingAnims);
  }

  void _updateAnimationIndices(String oldText, String newText) {
    int prefixLen = 0;
    while (prefixLen < oldText.length &&
        prefixLen < newText.length &&
        oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    int suffixLen = 0;
    while (suffixLen < oldText.length - prefixLen &&
        suffixLen < newText.length - prefixLen &&
        oldText[oldText.length - 1 - suffixLen] == newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final int addedCount = newText.length - oldText.length;

    if (addedCount > 0) {
      // Shift active animations
      for (var anim in _animations) {
        if (anim.startIndex >= prefixLen) {
          anim.startIndex += addedCount;
        }
      }

      // Add new animations
      final addedText = newText.substring(prefixLen, newText.length - suffixLen);
      // Skip animations for large pastes to prioritize responsiveness
      if (addedText.length < 50) {
        final now = DateTime.now();
        for (int i = 0; i < addedText.length; i++) {
          final char = addedText[i];
          // Skip whitespace animations
          if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
            continue;
          }
          _animations.add(
            CharacterAnimation(
              id: _nextAnimId++,
              startIndex: prefixLen + i,
              char: char,
              startTime: now,
            ),
          );
        }
        if (_animations.isNotEmpty) {
          _startTicker();
        }
      }
    } else if (addedCount < 0) {
      final removedCount = -addedCount;
      final int deleteStart = prefixLen;
      final int deleteEnd = prefixLen + removedCount;

      _animations.removeWhere((anim) => anim.startIndex >= deleteStart && anim.startIndex < deleteEnd);
      for (var anim in _animations) {
        if (anim.startIndex >= deleteEnd) {
          anim.startIndex -= removedCount;
        }
      }
    }
  }

  void _updateHeadingAnimations(String oldText, String newText) {
    final now = DateTime.now();
    final newLines = _getLineOffsets(newText);
    final oldLines = _getLineOffsets(oldText);

    final oldHeadingOffsets = <int>{};
    for (final line in oldLines) {
      final lineText = oldText.substring(line.start, line.end);
      if (_isHeadingText(lineText)) {
        oldHeadingOffsets.add(line.start);
      }
    }

    final currentHeadingOffsets = <int>{};
    for (final line in newLines) {
      final lineText = newText.substring(line.start, line.end);
      if (_isHeadingText(lineText)) {
        currentHeadingOffsets.add(line.start);

        if (!oldHeadingOffsets.contains(line.start) && !_headingAnimations.containsKey(line.start)) {
          _headingAnimations[line.start] = now;
          _startTicker();
        }
      }
    }

    _headingAnimations.removeWhere((offset, _) => !currentHeadingOffsets.contains(offset));
  }

  bool _isHeadingText(String text) {
    return text.startsWith('# ') ||
        text.startsWith('## ') ||
        text.startsWith('### ') ||
        text.startsWith('#### ') ||
        text.startsWith('##### ') ||
        text.startsWith('###### ');
  }

  List<TextRange> _getLineOffsets(String text) {
    final ranges = <TextRange>[];
    int start = 0;
    while (start < text.length) {
      int end = text.indexOf('\n', start);
      if (end == -1) {
        ranges.add(TextRange(start: start, end: text.length));
        break;
      } else {
        ranges.add(TextRange(start: start, end: end));
        start = end + 1;
      }
    }
    if (text.endsWith('\n')) {
      ranges.add(TextRange(start: text.length, end: text.length));
    }
    return ranges;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final String textVal = text;
    if (textVal.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final spans = <InlineSpan>[];
    final now = DateTime.now();
    final lines = _getLineOffsets(textVal);

    // Group active animations by line for O(1) checks
    final animsByLine = <int, List<CharacterAnimation>>{};
    for (final anim in _animations) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (anim.startIndex >= line.start && anim.startIndex < line.end) {
          animsByLine.putIfAbsent(i, () => []).add(anim);
          break;
        }
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineText = textVal.substring(line.start, line.end);
      final isHeading = _isHeadingText(lineText);

      TextStyle lineStyle = style ?? const TextStyle();

      if (isHeading) {
        double fontSize = lineStyle.fontSize ?? 18.0;
        if (lineText.startsWith('# ')) {
          fontSize = 32.0;
        } else if (lineText.startsWith('## ')) {
          fontSize = 26.0;
        } else if (lineText.startsWith('### ')) {
          fontSize = 22.0;
        } else {
          fontSize = 20.0;
        }

        if (_headingAnimations.containsKey(line.start)) {
          final startTime = _headingAnimations[line.start]!;
          final elapsed = now.difference(startTime).inMilliseconds;
          final progress = (elapsed / 300.0).clamp(0.0, 1.0);

          final FontWeight weight = FontWeight.lerp(FontWeight.normal, FontWeight.bold, progress)!;
          final double opacity = 0.6 + (0.4 * progress);

          lineStyle = lineStyle.copyWith(
            fontSize: fontSize,
            fontWeight: weight,
            color: lineStyle.color?.withValues(alpha: opacity),
          );
        } else {
          lineStyle = lineStyle.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          );
        }
      }

      final lineAnims = animsByLine[i];
      if (lineAnims == null || lineAnims.isEmpty) {
        spans.add(TextSpan(text: lineText, style: lineStyle));
      } else {
        final activeAnimMap = {for (var anim in lineAnims) anim.startIndex: anim};
        int lineIndex = line.start;
        int staticStart = line.start;

        while (lineIndex < line.end) {
          if (activeAnimMap.containsKey(lineIndex)) {
            if (lineIndex > staticStart) {
              spans.add(TextSpan(
                text: textVal.substring(staticStart, lineIndex),
                style: lineStyle,
              ));
            }

            final anim = activeAnimMap[lineIndex]!;
            final elapsed = now.difference(anim.startTime).inMilliseconds;
            final progress = (elapsed / anim.durationMs).clamp(0.0, 1.0);

            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: AnimatedCharacterWidget(
                char: anim.char,
                style: lineStyle,
                progress: progress,
              ),
            ));

            lineIndex++;
            staticStart = lineIndex;
          } else {
            lineIndex++;
          }
        }

        if (lineIndex > staticStart) {
          spans.add(TextSpan(
            text: textVal.substring(staticStart, lineIndex),
            style: lineStyle,
          ));
        }
      }

      if (line.end < textVal.length && textVal[line.end] == '\n') {
        spans.add(TextSpan(text: '\n', style: lineStyle));
      }
    }

    return TextSpan(style: style, children: spans);
  }
}

/// Overlays a custom breathing cursor over the text field.
class LivingCaretOverlay extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;

  const LivingCaretOverlay({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
  });

  @override
  State<LivingCaretOverlay> createState() => _LivingCaretOverlayState();
}

class _LivingCaretOverlayState extends State<LivingCaretOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  DateTime _lastTypingTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    widget.controller.addListener(_onTextOrSelectionChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextOrSelectionChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onTextOrSelectionChanged() {
    if (mounted) {
      setState(() {
        _lastTypingTime = DateTime.now();
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  RenderEditable? _findRenderEditable(RenderObject? renderObject) {
    if (renderObject is RenderEditable) {
      return renderObject;
    }
    RenderEditable? result;
    renderObject?.visitChildren((child) {
      final found = _findRenderEditable(child);
      if (found != null) {
        result = found;
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, widget.controller, widget.focusNode]),
              builder: (context, _) {
                if (!widget.focusNode.hasFocus) {
                  return const SizedBox.shrink();
                }

                final selection = widget.controller.selection;
                if (!selection.isCollapsed) {
                  return const SizedBox.shrink();
                }

                final renderEditable = _findRenderEditable(context.findRenderObject());
                if (renderEditable == null) {
                  return const SizedBox.shrink();
                }

                try {
                  final extent = selection.extent;
                  final rect = renderEditable.getLocalRectForCaret(extent);
                  
                  final RenderBox overlayBox = context.findRenderObject() as RenderBox;
                  final localTopLeft = overlayBox.globalToLocal(renderEditable.localToGlobal(rect.topLeft));
                  final localBottomRight = overlayBox.globalToLocal(renderEditable.localToGlobal(rect.bottomRight));
                  
                  final caretRect = Rect.fromPoints(localTopLeft, localBottomRight);

                  final timeSinceTyping = DateTime.now().difference(_lastTypingTime).inMilliseconds;
                  double opacity = 1.0;
                  if (timeSinceTyping > 500) {
                    final double pulseProgress = _pulseController.value;
                    final double pulsedOpacity = 0.7 + (0.3 * pulseProgress);
                    
                    final double blend = ((timeSinceTyping - 500) / 300.0).clamp(0.0, 1.0);
                    opacity = lerpDouble(1.0, pulsedOpacity, blend)!;
                  }

                  return CustomPaint(
                    painter: _CaretPainter(
                      rect: caretRect,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
                      cursorWidth: 2.0,
                      radius: const Radius.circular(1.0),
                    ),
                  );
                } catch (e) {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  final Rect rect;
  final Color color;
  final double cursorWidth;
  final Radius radius;

  _CaretPainter({
    required this.rect,
    required this.color,
    required this.cursorWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left, rect.top, cursorWidth, rect.height),
      radius,
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _CaretPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.color != color || oldDelegate.cursorWidth != cursorWidth;
  }
}

/// A Floating Action Button that slightly compresses under the finger on tap.
class LivingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final ShapeBorder? shape;
  final double? elevation;

  const LivingFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.shape,
    this.elevation,
  });

  @override
  State<LivingFloatingActionButton> createState() => _LivingFloatingActionButtonState();
}

class _LivingFloatingActionButtonState extends State<LivingFloatingActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 50));
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FloatingActionButton(
        onPressed: _handleTap,
        shape: widget.shape,
        elevation: widget.elevation,
        child: widget.child,
      ),
    );
  }
}

/// A Route that morphs from the FAB bounds to the full screen.
class FabMorphPageRoute<T> extends PageRouteBuilder<T> {
  final Rect fabBounds;

  FabMorphPageRoute({
    required this.fabBounds,
    required WidgetBuilder builder,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 400), // 350 - 500ms
          reverseTransitionDuration: const Duration(milliseconds: 350),
          opaque: true,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final double t = animation.value;
            if (animation.status == AnimationStatus.completed) {
              return child;
            }

            final double curvedT = Curves.easeInOutCubic.transform(t);

            final mediaQuery = MediaQuery.of(context);
            final screenBounds = Rect.fromLTWH(0, 0, mediaQuery.size.width, mediaQuery.size.height);

            final rect = Rect.lerp(fabBounds, screenBounds, curvedT)!;
            final radius = lerpDouble(16.0, 0.0, curvedT)!;

            final theme = Theme.of(context);
            const fabColor = Color(0xFF333333);
            final editorBgColor = theme.scaffoldBackgroundColor;
            final color = Color.lerp(fabColor, editorBgColor, curvedT)!;

            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      color: color,
                      child: Stack(
                        children: [
                          Positioned(
                            left: -rect.left,
                            top: -rect.top,
                            width: screenBounds.width,
                            height: screenBounds.height,
                            child: Opacity(
                              opacity: curvedT.clamp(0.0, 1.0),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

/// A wrapper that tracks layout movements of widgets across trees (FLIP).
class TactileFlipWrapper extends StatefulWidget {
  final String id;
  final Widget child;

  const TactileFlipWrapper({
    super.key,
    required this.id,
    required this.child,
  });

  static final Map<String, Offset> _savedPositions = {};

  @override
  State<TactileFlipWrapper> createState() => _TactileFlipWrapperState();
}

class _TactileFlipWrapperState extends State<TactileFlipWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Offset _currentOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offsetAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final newPos = box.localToGlobal(Offset.zero);

      if (TactileFlipWrapper._savedPositions.containsKey(widget.id)) {
        final oldPos = TactileFlipWrapper._savedPositions.remove(widget.id)!;
        final difference = oldPos - newPos;

        if (difference != Offset.zero) {
          setState(() {
            _currentOffset = difference;
          });

          _offsetAnimation = Tween<Offset>(
            begin: difference,
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

          _controller.forward(from: 0.0);
        }
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      try {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          TactileFlipWrapper._savedPositions[widget.id] = box.localToGlobal(Offset.zero);
          final idToClean = widget.id;
          Future.delayed(const Duration(seconds: 10), () {
            TactileFlipWrapper._savedPositions.remove(idToClean);
          });
        }
      } catch (_) {
        // Safe fallback if element is already defunct
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        final offset = _controller.isAnimating ? _offsetAnimation.value : _currentOffset;
        if (offset == Offset.zero) {
          return widget.child;
        }
        return Transform.translate(
          offset: offset,
          child: widget.child,
        );
      },
    );
  }
}

/// A Route that morphs from a Folder Card bounds to the full screen.
class FolderMorphPageRoute<T> extends PageRouteBuilder<T> {
  final Rect cardBounds;

  FolderMorphPageRoute({
    required this.cardBounds,
    required WidgetBuilder builder,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 450), // 350 - 500ms
          reverseTransitionDuration: const Duration(milliseconds: 400),
          opaque: true,
          barrierDismissible: false,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final double t = animation.value;
            if (animation.status == AnimationStatus.completed) {
              return child;
            }

            final double curvedT = Curves.easeInOutCubic.transform(t);

            final mediaQuery = MediaQuery.of(context);
            final screenBounds = Rect.fromLTWH(0, 0, mediaQuery.size.width, mediaQuery.size.height);

            final rect = Rect.lerp(cardBounds, screenBounds, curvedT)!;
            final radius = lerpDouble(20.0, 0.0, curvedT)!;

            final theme = Theme.of(context);
            final cardColor = theme.cardColor;
            final screenColor = theme.scaffoldBackgroundColor;
            final color = Color.lerp(cardColor, screenColor, curvedT)!;

            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      color: color,
                      child: Stack(
                        children: [
                          Positioned(
                            left: -rect.left,
                            top: -rect.top,
                            width: screenBounds.width,
                            height: screenBounds.height,
                            child: Opacity(
                              opacity: curvedT.clamp(0.0, 1.0),
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
}
