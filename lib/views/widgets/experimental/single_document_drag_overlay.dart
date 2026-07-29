import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../rich_text_controller.dart';
import '../new_single_document_editor.dart';

class _ShortPressDragGestureRecognizer extends PanGestureRecognizer {
  Timer? _pressTimer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 150), () {
      resolve(GestureDisposition.accepted);
    });
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

  const SingleDocumentDragOverlay({
    super.key,
    required this.controller,
    required this.sdeKey,
    required this.child,
    this.onDragStateChanged,
    this.scrollController,
  });

  @override
  State<SingleDocumentDragOverlay> createState() => _SingleDocumentDragOverlayState();
}

class _SingleDocumentDragOverlayState extends State<SingleDocumentDragOverlay> {
  Offset? _dragStartPos;
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
            final localPos = renderBox.globalToLocal(globalPosition);
            final textEditingContext = context as Element;
            final editable = textEditingContext.findRenderObject();
            
            if (editable != null && editable.runtimeType.toString().contains('RenderEditable')) {
              try {
                final dynamic renderEditable = editable;
                final textPosition = renderEditable.getPositionForPoint(localPos);
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

  void _handlePanStart(DragStartDetails details) {
    _dragStartPos = details.globalPosition;
    _lastCurrentPos = details.globalPosition;
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    widget.onDragStateChanged?.call(true);
    _updateSelection(details.globalPosition, details.globalPosition);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartPos != null) {
      _lastCurrentPos = details.globalPosition;
      _updateSelection(_dragStartPos!, details.globalPosition);
      _startAutoScrollIfNeeded(details.globalPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _dragStartPos = null;
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

    const double scrollEdgeThreshold = 80.0;
    double scrollDelta = 0;

    if (dy > screenHeight - scrollEdgeThreshold) {
      final ratio = ((dy - (screenHeight - scrollEdgeThreshold)) / scrollEdgeThreshold).clamp(0.1, 1.0);
      scrollDelta = 12.0 * ratio;
    } else if (dy < scrollEdgeThreshold) {
      final ratio = ((scrollEdgeThreshold - dy) / scrollEdgeThreshold).clamp(0.1, 1.0);
      scrollDelta = -12.0 * ratio;
    }

    if (scrollDelta != 0) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
          if (_dragStartPos != null && _lastCurrentPos != null && scrollController.hasClients) {
            final newOffset = (scrollController.offset + scrollDelta).clamp(
              0.0,
              scrollController.position.maxScrollExtent,
            );
            if (newOffset != scrollController.offset) {
              scrollController.jumpTo(newOffset);
              _updateSelection(_dragStartPos!, _lastCurrentPos!);
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

  void _updateSelection(Offset startPos, Offset currentPos) {
    final startOffset = _getGlobalOffsetFromPosition(startPos);
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
    return RawGestureDetector(
      key: _overlayKey,
      gestures: {
        _ShortPressDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<_ShortPressDragGestureRecognizer>(
          () => _ShortPressDragGestureRecognizer(),
          (_ShortPressDragGestureRecognizer instance) {
            instance
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
        final boxRect = localTopLeft & renderBox.size;

        final clampedStart = selStart.clamp(segStart, segEnd);
        final clampedEnd = selEnd.clamp(segStart, segEnd);

        final localStartOffset = clampedStart - segStart;
        final localEndOffset = clampedEnd - segStart;

        final editable = (context as Element).findRenderObject();
        if (editable != null && editable.runtimeType.toString().contains('RenderEditable')) {
          try {
            final dynamic renderEditable = editable;
            final TextSelection localSel = TextSelection(
              baseOffset: localStartOffset,
              extentOffset: localEndOffset,
            );
            final List<TextBox> boxes = renderEditable.getBoxesForSelection(localSel);

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
            } else {
              final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(3));
              canvas.drawRRect(rrect, paint);
            }
          } catch (_) {
            final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(3));
            canvas.drawRRect(rrect, paint);
          }
        } else {
          final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(3));
          canvas.drawRRect(rrect, paint);
        }
      }
    }

    if (startHandlePos != null) {
      canvas.drawCircle(startHandlePos, 6, handlePaint);
    }
    if (endHandlePos != null) {
      canvas.drawCircle(endHandlePos, 6, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SDESelectionHighlightPainter oldDelegate) {
    return oldDelegate.controller.selection != controller.selection;
  }
}
