import 'package:flutter/material.dart';
import '../rich_text_controller.dart';
import '../new_single_document_editor.dart';

class SingleDocumentDragOverlay extends StatefulWidget {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final Widget child;

  const SingleDocumentDragOverlay({
    super.key,
    required this.controller,
    required this.sdeKey,
    required this.child,
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
              final int segStart = _getSegmentStartOffset(segmentIndex);
              if (globalPosition.dy < boxRect.top) {
                closestOffset = segStart;
              } else {
                final textLength = widget.controller.text.length;
                closestOffset = (segStart + 50).clamp(0, textLength).toInt();
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

  void _handlePointerDown(PointerDownEvent event) {
    _dragStartPos = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dragStartPos == null) return;

    final distance = (event.position - _dragStartPos!).distance;
    if (distance > 5.0) {
      final startOffset = _getGlobalOffsetFromPosition(_dragStartPos!);
      final endOffset = _getGlobalOffsetFromPosition(event.position);

      final newSelection = TextSelection(
        baseOffset: startOffset,
        extentOffset: endOffset,
      );

      if (widget.controller.selection != newSelection) {
        widget.controller.selection = newSelection;
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _dragStartPos = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: _overlayKey,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
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
      ..color = const Color(0x403B82F6) // Modern semi-transparent primary blue
      ..style = PaintingStyle.fill;

    final text = controller.text;
    final lines = text.split('\n');
    int currentGlobalOffset = 0;

    for (int segmentIndex = 0; segmentIndex < lines.length; segmentIndex++) {
      final lineLength = lines[segmentIndex].length;
      final segStart = currentGlobalOffset;
      final segEnd = segStart + lineLength;
      currentGlobalOffset = segEnd + 1; // +1 for newline

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

            for (final box in boxes) {
              final Rect rect = Rect.fromLTRB(
                localTopLeft.dx + box.left,
                localTopLeft.dy + box.top,
                localTopLeft.dx + box.right,
                localTopLeft.dy + box.bottom,
              );
              final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
              canvas.drawRRect(rrect, paint);
            }
          } catch (_) {
            // Fallback: draw full line highlight box if RenderEditable boxes fail
            final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(4));
            canvas.drawRRect(rrect, paint);
          }
        } else {
          // Fallback: draw line box
          final RRect rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(4));
          canvas.drawRRect(rrect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SDESelectionHighlightPainter oldDelegate) {
    return oldDelegate.controller.selection != controller.selection;
  }
}
