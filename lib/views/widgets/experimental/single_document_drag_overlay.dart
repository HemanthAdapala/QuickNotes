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
        widget.controller.notifyListeners();
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _dragStartPos = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
