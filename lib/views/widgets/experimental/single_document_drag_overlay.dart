import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../rich_text_controller.dart';
import '../new_single_document_editor.dart';

class _LongPressDragGestureRecognizer extends PanGestureRecognizer {
  Timer? _pressTimer;
  bool _isLongPressAccepted = false;
  Offset? _initialPosition;
  void Function(Offset position)? onLongPressDetected;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _isLongPressAccepted = false;
    _initialPosition = event.position;
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 200), () {
      _isLongPressAccepted = true;
      HapticFeedback.mediumImpact();
      if (_initialPosition != null) {
        onLongPressDetected?.call(_initialPosition!);
      }
      resolve(GestureDisposition.accepted);
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && !_isLongPressAccepted && _initialPosition != null) {
      final delta = (event.position - _initialPosition!).distance;
      if (delta > 12.0) {
        _pressTimer?.cancel();
        resolve(GestureDisposition.rejected);
      }
    }
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _pressTimer?.cancel();
    super.rejectGesture(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    _pressTimer?.cancel();
    super.acceptGesture(pointer);
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }
}

class SingleDocumentDragOverlay extends StatefulWidget {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final Widget child;
  final ValueChanged<bool>? onDragStateChanged;
  final ScrollController? scrollController;
  final bool isSelectionMode;

  const SingleDocumentDragOverlay({
    super.key,
    required this.controller,
    required this.sdeKey,
    required this.child,
    this.onDragStateChanged,
    this.scrollController,
    this.isSelectionMode = true,
  });

  @override
  State<SingleDocumentDragOverlay> createState() => _SingleDocumentDragOverlayState();
}

class _SingleDocumentDragOverlayState extends State<SingleDocumentDragOverlay> {
  Offset? _dragStartPos;
  int? _dragStartOffset;
  Offset? _lastCurrentPos;
  Timer? _autoScrollTimer;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  RenderObject? _findRenderEditable(RenderObject? renderObject) {
    if (renderObject == null) return null;
    if (renderObject.runtimeType.toString().contains('RenderEditable')) {
      return renderObject;
    }
    RenderObject? found;
    renderObject.visitChildren((child) {
      if (found == null) {
        found = _findRenderEditable(child);
      }
    });
    return found;
  }

  int _getGlobalOffsetFromPosition(Offset globalPosition) {
    final sdeState = widget.sdeKey.currentState;
    if (sdeState == null) return widget.controller.text.length;

    int closestOffset = widget.controller.text.length;
    double minDistance = double.infinity;

    sdeState.focusNodes.forEach((segmentIndex, focusNode) {
      final context = focusNode.context;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final boxPosition = renderBox.localToGlobal(Offset.zero);
          final boxRect = boxPosition & renderBox.size;
          
          if (globalPosition.dy >= boxRect.top && globalPosition.dy <= boxRect.bottom) {
            final renderEditable = _findRenderEditable(renderBox);
            if (renderEditable != null && renderEditable is RenderBox) {
              try {
                final dynamic editable = renderEditable;
                final editableLocalPos = renderEditable.globalToLocal(globalPosition);
                final textPosition = editable.getPositionForPoint(editableLocalPos);
                final localOffset = textPosition.offset;
                
                final int segStart = _getSegmentStartOffset(segmentIndex);
                closestOffset = (segStart + localOffset).clamp(0, widget.controller.text.length).toInt();
                minDistance = 0;
              } catch (_) {}
            }
          } else {
            final double dist = (globalPosition.dy - boxRect.center.dy).abs();
            if (dist < minDistance) {
              minDistance = dist;
              if (globalPosition.dy < boxRect.top) {
                closestOffset = _getSegmentStartOffset(segmentIndex);
              } else {
                closestOffset = _getSegmentEndOffset(segmentIndex);
              }
            }
          }
        }
      }
    });

    return closestOffset;
  }

  int _getSegmentStartOffset(int segmentIndex) {
    final text = widget.controller.text;
    final lines = text.split('\n');
    int currentOffset = 0;
    for (int i = 0; i < lines.length && i < segmentIndex; i++) {
      currentOffset += lines[i].length + 1;
    }
    return currentOffset.clamp(0, text.length);
  }

  int _getSegmentEndOffset(int segmentIndex) {
    final text = widget.controller.text;
    final lines = text.split('\n');
    int currentOffset = 0;
    for (int i = 0; i < lines.length && i <= segmentIndex; i++) {
      currentOffset += lines[i].length;
      if (i < segmentIndex) currentOffset += 1;
    }
    return currentOffset.clamp(0, text.length);
  }

  TextRange _getWordBoundaryAtOffset(int offset) {
    final text = widget.controller.text;
    if (text.isEmpty) return const TextRange(start: 0, end: 0);
    int clamped = offset.clamp(0, text.length);

    if (clamped < text.length && !_isWordChar(text[clamped])) {
      if (clamped > 0 && _isWordChar(text[clamped - 1])) {
        clamped--;
      } else {
        int right = clamped;
        while (right < text.length && !_isWordChar(text[right])) {
          right++;
        }
        if (right < text.length) {
          clamped = right;
        } else {
          int left = clamped;
          while (left > 0 && !_isWordChar(text[left - 1])) {
            left--;
          }
          if (left > 0) clamped = left - 1;
        }
      }
    }

    int start = clamped;
    int end = clamped;

    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    while (end < text.length && _isWordChar(text[end])) {
      end++;
    }

    if (start == end && text.isNotEmpty) {
      start = clamped.clamp(0, text.length - 1);
      end = (start + 1).clamp(0, text.length);
    }

    return TextRange(start: start, end: end);
  }

  bool _isWordChar(String char) {
    return RegExp(r'[a-zA-Z0-9_\-\u00C0-\u024F]').hasMatch(char);
  }

  void _onLongPressDetected(Offset position) {
    if (!widget.isSelectionMode) return;
    _dragStartPos = position;
    _lastCurrentPos = position;

    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    widget.onDragStateChanged?.call(true);

    final rawOffset = _getGlobalOffsetFromPosition(position);
    final wordRange = _getWordBoundaryAtOffset(rawOffset);

    _dragStartOffset = wordRange.start;
    final initialSelection = TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );

    widget.controller.selection = initialSelection;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.isSelectionMode) return;
    if (_dragStartOffset == null) {
      _onLongPressDetected(details.globalPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.isSelectionMode) return;
    if (_dragStartOffset != null) {
      _lastCurrentPos = details.globalPosition;
      _updateSelectionWithStartOffset(_dragStartOffset!, details.globalPosition);
      _startAutoScrollIfNeeded(details.globalPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.isSelectionMode) return;
    _dragStartPos = null;
    _dragStartOffset = null;
    _lastCurrentPos = null;
    _stopAutoScroll();
    widget.onDragStateChanged?.call(false);
  }

  void _startAutoScrollIfNeeded(Offset currentPos) {
    final scrollController = widget.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final dy = currentPos.dy;

    const double scrollEdgeThreshold = 100.0;
    double scrollDelta = 0;

    if (dy > screenHeight - scrollEdgeThreshold) {
      final ratio = ((dy - (screenHeight - scrollEdgeThreshold)) / scrollEdgeThreshold).clamp(0.1, 1.0);
      scrollDelta = 35.0 * ratio;
    } else if (dy < scrollEdgeThreshold) {
      final ratio = ((scrollEdgeThreshold - dy) / scrollEdgeThreshold).clamp(0.1, 1.0);
      scrollDelta = -35.0 * ratio;
    }

    if (scrollDelta != 0) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          if (_dragStartOffset != null && _lastCurrentPos != null && scrollController.hasClients) {
            final newOffset = (scrollController.offset + scrollDelta).clamp(
              0.0,
              scrollController.position.maxScrollExtent,
            );
            if (newOffset != scrollController.offset) {
              scrollController.jumpTo(newOffset);
              _updateSelectionWithStartOffset(_dragStartOffset!, _lastCurrentPos!);
            }
          }
        });
      }
    } else {
      _stopAutoScroll();
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _updateSelectionWithStartOffset(int startOffset, Offset currentPos) {
    final endOffset = _getGlobalOffsetFromPosition(currentPos);

    final newSelection = TextSelection(
      baseOffset: startOffset,
      extentOffset: endOffset,
    );

    if (widget.controller.selection != newSelection) {
      widget.controller.selection = newSelection;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelectionMode) {
      return widget.child;
    }

    return RawGestureDetector(
      key: _overlayKey,
      gestures: {
        _LongPressDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<_LongPressDragGestureRecognizer>(
          () => _LongPressDragGestureRecognizer(),
          (_LongPressDragGestureRecognizer instance) {
            instance
              ..onLongPressDetected = _onLongPressDetected
              ..onStart = _handlePanStart
              ..onUpdate = _handlePanUpdate
              ..onEnd = _handlePanEnd;
          },
        ),
      },
      behavior: HitTestBehavior.translucent,
      child: CustomPaint(
        foregroundPainter: _SDESelectionHighlightPainter(
          controller: widget.controller,
          sdeKey: widget.sdeKey,
          overlayKey: _overlayKey,
        ),
        child: widget.child,
      ),
    );
  }
}

class _SDESelectionHighlightPainter extends CustomPainter {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final GlobalKey overlayKey;

  _SDESelectionHighlightPainter({
    required this.controller,
    required this.sdeKey,
    required this.overlayKey,
  }) : super(repaint: controller);

  RenderObject? _findRenderEditable(RenderObject? renderObject) {
    if (renderObject == null) return null;
    if (renderObject.runtimeType.toString().contains('RenderEditable')) {
      return renderObject;
    }
    RenderObject? found;
    renderObject.visitChildren((child) {
      if (found == null) {
        found = _findRenderEditable(child);
      }
    });
    return found;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final sdeState = sdeKey.currentState;
    if (sdeState == null) return;

    final overlayRenderBox = overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayRenderBox == null || !overlayRenderBox.hasSize) return;

    final selStart = selection.start;
    final selEnd = selection.end;

    final paint = Paint()
      ..color = const Color(0x503B82F6) // Semi-transparent selection blue
      ..style = PaintingStyle.fill;

    final handlePaint = Paint()
      ..color = const Color(0xFF2563EB) // Solid primary drag handle blue
      ..style = PaintingStyle.fill;

    final handleInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final text = controller.text;
    final lines = text.split('\n');
    int currentGlobalOffset = 0;

    Offset? startHandlePos;
    Offset? endHandlePos;

    for (int segmentIndex = 0; segmentIndex < lines.length; segmentIndex++) {
      final lineLength = lines[segmentIndex].length;
      final segStart = currentGlobalOffset;
      final segEnd = segStart + lineLength;
      currentGlobalOffset = segEnd + 1;

      if (selEnd >= segStart && selStart <= segEnd) {
        final focusNode = sdeState.focusNodes[segmentIndex];
        if (focusNode == null) continue;

        final context = focusNode.context;
        if (context == null) continue;

        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) continue;

        final localTopLeft = overlayRenderBox.globalToLocal(renderBox.localToGlobal(Offset.zero));

        final clampedStart = selStart.clamp(segStart, segEnd);
        final clampedEnd = selEnd.clamp(segStart, segEnd);

        final localStartOffset = clampedStart - segStart;
        final localEndOffset = clampedEnd - segStart;

        final renderEditable = _findRenderEditable(renderBox);
        if (renderEditable != null && renderEditable is RenderBox) {
          try {
            final dynamic editable = renderEditable;
            final TextSelection localSel = TextSelection(
              baseOffset: localStartOffset,
              extentOffset: localEndOffset,
            );
            final List<TextBox> boxes = editable.getBoxesForSelection(localSel);

            if (boxes.isNotEmpty) {
              for (final box in boxes) {
                final Rect rect = Rect.fromLTRB(
                  localTopLeft.dx + box.left,
                  localTopLeft.dy + box.top,
                  localTopLeft.dx + box.right,
                  localTopLeft.dy + box.bottom,
                );
                final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
                canvas.drawRRect(rrect, paint);

                if (startHandlePos == null && clampedStart == segStart + localStartOffset) {
                  startHandlePos = Offset(rect.left, rect.bottom);
                }
                endHandlePos = Offset(rect.right, rect.bottom);
              }
            }
          } catch (_) {}
        }
      }
    }

    if (startHandlePos != null) {
      canvas.drawCircle(startHandlePos, 7, handlePaint);
      canvas.drawCircle(startHandlePos, 3, handleInnerPaint);
    }
    if (endHandlePos != null) {
      canvas.drawCircle(endHandlePos, 7, handlePaint);
      canvas.drawCircle(endHandlePos, 3, handleInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SDESelectionHighlightPainter oldDelegate) {
    return oldDelegate.controller.selection != controller.selection;
  }
}
