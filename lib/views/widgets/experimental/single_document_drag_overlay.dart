import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../rich_text_controller.dart';
import '../new_single_document_editor.dart';

class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class SingleDocumentDragOverlay extends StatefulWidget {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final Widget child;
  final ValueChanged<bool>? onDragStateChanged;

  const SingleDocumentDragOverlay({
    super.key,
    required this.controller,
    required this.sdeKey,
    required this.child,
    this.onDragStateChanged,
  });

  @override
  State<SingleDocumentDragOverlay> createState() => _SingleDocumentDragOverlayState();
}

class _SingleDocumentDragOverlayState extends State<SingleDocumentDragOverlay> {
  Offset? _dragStartPos;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
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
    widget.onDragStateChanged?.call(true);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartPos == null) return;

    final distance = (details.globalPosition - _dragStartPos!).distance;
    if (distance > 3.0) {
      final startOffset = _getGlobalOffsetFromPosition(_dragStartPos!);
      final endOffset = _getGlobalOffsetFromPosition(details.globalPosition);

      final newSelection = TextSelection(
        baseOffset: startOffset,
        extentOffset: endOffset,
      );

      if (widget.controller.selection != newSelection) {
        widget.controller.selection = newSelection;
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _dragStartPos = null;
    widget.onDragStateChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      key: _overlayKey,
      gestures: {
        _EagerPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
          () => _EagerPanGestureRecognizer(),
          (_EagerPanGestureRecognizer instance) {
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

    // Draw handles at start & end of selection
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
