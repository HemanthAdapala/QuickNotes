import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rich_text_controller.dart';
import 'new_single_document_editor.dart';

class _LongPressDragGestureRecognizer extends PanGestureRecognizer {
  Timer? _pressTimer;
  bool _isLongPressAccepted = false;
  Offset? _initialPosition;
  void Function(Offset position)? onLongPressDetected;
  bool Function(Offset globalPosition)? isTouchOnHandle;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _isLongPressAccepted = false;
    _initialPosition = event.position;
    _pressTimer?.cancel();

    if (isTouchOnHandle?.call(event.position) == true) {
      _isLongPressAccepted = true;
      resolve(GestureDisposition.accepted);
      return;
    }

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
    if (event is PointerMoveEvent &&
        !_isLongPressAccepted &&
        _initialPosition != null) {
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

class ContextualBar extends StatelessWidget {
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onSelectAll;
  final VoidCallback? onShare;

  const ContextualBar({
    super.key,
    this.onCut,
    this.onCopy,
    this.onSelectAll,
    this.onShare,
  });

  Widget _buildItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required double width,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF333333)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF333333),
                fontSize: 11,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 16,
                offset: Offset(0, 0),
                spreadRadius: 0,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildItem(
                icon: Icons.content_cut_rounded,
                label: 'Cut',
                onTap: onCut,
                width: 40,
              ),
              const SizedBox(width: 10),
              _buildItem(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: onCopy,
                width: 40,
              ),
              const SizedBox(width: 10),
              _buildItem(
                icon: Icons.select_all_rounded,
                label: 'Select all',
                onTap: onSelectAll,
                width: 65,
              ),
              const SizedBox(width: 10),
              _buildItem(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: onShare,
                width: 40,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SingleDocumentDragOverlay extends StatefulWidget {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final Widget child;
  final ValueChanged<bool>? onDragStateChanged;
  final ScrollController? scrollController;
  final bool isSelectionMode;
  final Offset? initialTapPosition;

  const SingleDocumentDragOverlay({
    super.key,
    required this.controller,
    required this.sdeKey,
    required this.child,
    this.onDragStateChanged,
    this.scrollController,
    this.isSelectionMode = true,
    this.initialTapPosition,
  });

  @override
  State<SingleDocumentDragOverlay> createState() =>
      _SingleDocumentDragOverlayState();
}

class _SingleDocumentDragOverlayState
    extends State<SingleDocumentDragOverlay> {
  int? _dragStartOffset;
  int? _initialWordStart;
  int? _initialWordEnd;
  Offset? _lastCurrentPos;
  Timer? _autoScrollTimer;
  final GlobalKey _overlayKey = GlobalKey();

  Offset? _startHandlePos;
  Offset? _endHandlePos;
  bool _isDraggingStartHandle = false;
  bool _isDraggingEndHandle = false;

  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  bool _pointerScrolled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _hideKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hideKeyboard();
      if (mounted && widget.initialTapPosition != null) {
        _selectWordAtPosition(widget.initialTapPosition!);
      }
    });
  }

  bool _isEditorFocused() {
    final sdeState = widget.sdeKey.currentState;
    if (sdeState == null) return false;
    return sdeState.focusNodes.values.any((n) => n.hasFocus);
  }

  void _selectWordAtPosition(Offset position) {
    final rawOffset = _getGlobalOffsetFromPosition(position);
    final wordRange = _getWordBoundaryAtOffset(rawOffset);
    final selection = TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );
    widget.controller.selection = selection;
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

  void _updateHandlePositions(Offset? start, Offset? end) {
    final changed = _startHandlePos != start || _endHandlePos != end;
    _startHandlePos = start;
    _endHandlePos = end;

    if (changed && mounted) {
      final isDragging = _dragStartOffset != null ||
          _isDraggingStartHandle ||
          _isDraggingEndHandle;
      if (!isDragging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
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

    final textSegments = sdeState.textSegments;
    if (textSegments.isEmpty) return widget.controller.text.length;

    int closestOffset = widget.controller.text.length;
    double minDistance = double.infinity;

    for (final segment in textSegments) {
      final containerKey = sdeState.segmentContainerKeys[segment.segmentIndex];
      final key = sdeState.textFieldKeys[segment.segmentIndex];
      final focusNode = sdeState.focusNodes[segment.segmentIndex];
      final context = containerKey?.currentContext ??
          key?.currentContext ??
          focusNode?.context;
      if (context == null) continue;

      final outerRenderBox = context.findRenderObject() as RenderBox?;
      if (outerRenderBox == null || !outerRenderBox.hasSize) continue;

      final renderEditable = _findRenderEditable(outerRenderBox);
      if (renderEditable == null ||
          renderEditable is! RenderBox ||
          !renderEditable.hasSize) {
        continue;
      }

      final lineTopLeft = outerRenderBox.localToGlobal(Offset.zero);
      final lineRect = lineTopLeft & outerRenderBox.size;

      final subController =
          sdeState.getSegmentController(segment.segmentIndex);
      final String displayedText = subController?.text ?? '';

      if (globalPosition.dy >= lineRect.top &&
          globalPosition.dy <= lineRect.bottom) {
        try {
          final dynamic editable = renderEditable;
          final TextPosition textPosition =
              editable.getPositionForPoint(globalPosition);
          final localDisplayedOffset = textPosition.offset;

          final int rawLineLen = segment.end - segment.start;
          final int rawOffsetInLine =
              localDisplayedOffset.clamp(0, rawLineLen);
          return (segment.start + rawOffsetInLine)
              .clamp(0, widget.controller.text.length)
              .toInt();
        } catch (_) {}
      } else {
        final double dist = (globalPosition.dy - lineRect.center.dy).abs();
        if (dist < minDistance) {
          minDistance = dist;
          if (globalPosition.dy < lineRect.top) {
            closestOffset = segment.start;
          } else {
            closestOffset = segment.end;
          }
        }
      }
    }

    return closestOffset;
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

  bool _isTouchOnHandle(Offset globalPos) {
    if (_isDraggingStartHandle || _isDraggingEndHandle) return true;

    final selection = widget.controller.selection;
    if (!selection.isValid || selection.isCollapsed) return false;
    if (_overlayKey.currentContext == null) return false;

    final overlayBox =
        _overlayKey.currentContext!.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize) return false;

    final localTouch = overlayBox.globalToLocal(globalPos);
    const double handleHitRadius = 40.0;

    if (_startHandlePos != null &&
        (localTouch - _startHandlePos!).distance <= handleHitRadius) {
      return true;
    }
    if (_endHandlePos != null &&
        (localTouch - _endHandlePos!).distance <= handleHitRadius) {
      return true;
    }

    return false;
  }

  void _onLongPressDetected(Offset position) {
    if (!widget.isSelectionMode) return;
    _lastCurrentPos = position;

    _setFocusGated(true);
    _hideKeyboard();
    widget.onDragStateChanged?.call(true);

    final rawOffset = _getGlobalOffsetFromPosition(position);
    final wordRange = _getWordBoundaryAtOffset(rawOffset);

    _initialWordStart = wordRange.start;
    _initialWordEnd = wordRange.end;
    _dragStartOffset = wordRange.start;

    final initialSelection = TextSelection(
      baseOffset: wordRange.start,
      extentOffset: wordRange.end,
    );

    widget.controller.selection = initialSelection;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.isSelectionMode) return;

    final selection = widget.controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (hasSelection && _overlayKey.currentContext != null) {
      final overlayBox =
          _overlayKey.currentContext!.findRenderObject() as RenderBox?;
      if (overlayBox != null && overlayBox.hasSize) {
        final localTouch = overlayBox.globalToLocal(details.globalPosition);
        const double handleHitRadius = 40.0;

        if (_startHandlePos != null &&
            (localTouch - _startHandlePos!).distance <= handleHitRadius) {
          _isDraggingStartHandle = true;
          _isDraggingEndHandle = false;
          _lastCurrentPos = details.globalPosition;
          widget.onDragStateChanged?.call(true);
          _startAutoScrollIfNeeded(details.globalPosition);
          setState(() {});
          return;
        }

        if (_endHandlePos != null &&
            (localTouch - _endHandlePos!).distance <= handleHitRadius) {
          _isDraggingEndHandle = true;
          _isDraggingStartHandle = false;
          _lastCurrentPos = details.globalPosition;
          widget.onDragStateChanged?.call(true);
          _startAutoScrollIfNeeded(details.globalPosition);
          setState(() {});
          return;
        }
      }
    }

    _isDraggingStartHandle = false;
    _isDraggingEndHandle = false;

    if (_dragStartOffset == null) {
      _onLongPressDetected(details.globalPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.isSelectionMode) return;

    if (_isDraggingStartHandle) {
      _lastCurrentPos = details.globalPosition;
      _updateSelectionForStartHandle(details.globalPosition);
      _startAutoScrollIfNeeded(details.globalPosition);
      setState(() {});
    } else if (_isDraggingEndHandle) {
      _lastCurrentPos = details.globalPosition;
      _updateSelectionForEndHandle(details.globalPosition);
      _startAutoScrollIfNeeded(details.globalPosition);
      setState(() {});
    } else if (_dragStartOffset != null) {
      _lastCurrentPos = details.globalPosition;
      _updateSelectionWithStartOffset(
          _dragStartOffset!, details.globalPosition);
      _startAutoScrollIfNeeded(details.globalPosition);
      setState(() {});
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.isSelectionMode) return;
    _isDraggingStartHandle = false;
    _isDraggingEndHandle = false;
    _dragStartOffset = null;
    _initialWordStart = null;
    _initialWordEnd = null;
    _lastCurrentPos = null;
    _stopAutoScroll();
    widget.onDragStateChanged?.call(false);
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _updateSelectionForStartHandle(Offset currentPos) {
    final currentOffset = _getGlobalOffsetFromPosition(currentPos);
    final endOffset = widget.controller.selection.end;
    int newBase = currentOffset;
    int newExtent = endOffset;
    if (newBase > newExtent) {
      final temp = newBase;
      newBase = newExtent;
      newExtent = temp;
      _isDraggingStartHandle = false;
      _isDraggingEndHandle = true;
    }
    final newSel = TextSelection(baseOffset: newBase, extentOffset: newExtent);
    if (widget.controller.selection != newSel) {
      HapticFeedback.selectionClick();
      widget.controller.selection = newSel;
    }
  }

  void _updateSelectionForEndHandle(Offset currentPos) {
    final currentOffset = _getGlobalOffsetFromPosition(currentPos);
    final startOffset = widget.controller.selection.start;
    int newBase = startOffset;
    int newExtent = currentOffset;
    if (newExtent < newBase) {
      final temp = newBase;
      newBase = newExtent;
      newExtent = temp;
      _isDraggingStartHandle = true;
      _isDraggingEndHandle = false;
    }
    final newSel = TextSelection(baseOffset: newBase, extentOffset: newExtent);
    if (widget.controller.selection != newSel) {
      HapticFeedback.selectionClick();
      widget.controller.selection = newSel;
    }
  }

  double _calculateScrollDelta(Offset pos) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final dy = pos.dy;

    const double bottomScrollThreshold = 150.0;
    const double topScrollThreshold = 140.0;
    double scrollDelta = 0;

    if (dy > screenHeight - bottomScrollThreshold) {
      final ratio =
          ((dy - (screenHeight - bottomScrollThreshold)) / bottomScrollThreshold)
              .clamp(0.1, 1.0);
      scrollDelta = (10.0 + 40.0 * ratio * ratio);
    } else if (dy < topScrollThreshold) {
      final ratio =
          ((topScrollThreshold - dy) / topScrollThreshold).clamp(0.1, 1.0);
      scrollDelta = -(10.0 + 40.0 * ratio * ratio);
    }
    return scrollDelta;
  }

  void _startAutoScrollIfNeeded(Offset currentPos) {
    _lastCurrentPos = currentPos;
    final scrollController = widget.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final initialDelta = _calculateScrollDelta(currentPos);

    if (initialDelta != 0) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer =
            Timer.periodic(const Duration(milliseconds: 16), (_) {
          final isDragging = _dragStartOffset != null ||
              _isDraggingStartHandle ||
              _isDraggingEndHandle;
          if (isDragging &&
              _lastCurrentPos != null &&
              scrollController.hasClients) {
            final delta = _calculateScrollDelta(_lastCurrentPos!);
            if (delta == 0) {
              _stopAutoScroll();
              return;
            }

            final newOffset = (scrollController.offset + delta).clamp(
              0.0,
              scrollController.position.maxScrollExtent,
            );
            if (newOffset != scrollController.offset) {
              scrollController.jumpTo(newOffset);
              if (_isDraggingStartHandle) {
                _updateSelectionForStartHandle(_lastCurrentPos!);
              } else if (_isDraggingEndHandle) {
                _updateSelectionForEndHandle(_lastCurrentPos!);
              } else if (_dragStartOffset != null) {
                _updateSelectionWithStartOffset(
                    _dragStartOffset!, _lastCurrentPos!);
              }
            }
          } else {
            _stopAutoScroll();
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
    if (_initialWordStart == null || _initialWordEnd == null) return;
    final currentOffset = _getGlobalOffsetFromPosition(currentPos);

    int base;
    int extent;

    if (currentOffset > _initialWordEnd!) {
      base = _initialWordStart!;
      extent = currentOffset;
    } else if (currentOffset < _initialWordStart!) {
      base = _initialWordEnd!;
      extent = currentOffset;
    } else {
      base = _initialWordStart!;
      extent = _initialWordEnd!;
    }

    final newSelection = TextSelection(
      baseOffset: base,
      extentOffset: extent,
    );

    if (widget.controller.selection != newSelection) {
      HapticFeedback.selectionClick();
      widget.controller.selection = newSelection;
    }
  }

  void _setFocusGated(bool gated) {
    debugPrint('[KB_LOG] _setFocusGated($gated)');
    final sdeState = widget.sdeKey.currentState;
    if (sdeState != null) {
      for (final node in sdeState.focusNodes.values) {
        node.canRequestFocus = !gated;
      }
    }
  }

  void _hideKeyboard() {
    debugPrint('[KB_LOG] _hideKeyboard() called');
    FocusManager.instance.primaryFocus?.unfocus();
    final sdeState = widget.sdeKey.currentState;
    if (sdeState != null) {
      for (final node in sdeState.focusNodes.values) {
        if (node.hasFocus) {
          node.unfocus();
        }
      }
    }
  }

  bool _wasEditorFocusedOnDown = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.isSelectionMode) return;
    if (_isDraggingStartHandle || _isDraggingEndHandle) return;

    _pointerDownPos = event.position;
    _pointerDownTime = DateTime.now();
    _pointerScrolled = false;

    _wasEditorFocusedOnDown = _isEditorFocused();
    debugPrint('[KB_LOG] PointerDown: Editor already focused = $_wasEditorFocusedOnDown');

    // Mode 2 (Editor Not Focused): Gate focus during pending gesture window so TextInput.attach() is never called during long press.
    // Mode 1 (Editor Already Focused): Do NOT gate focus so active editing focus is preserved during word-to-word cursor movement.
    if (!_wasEditorFocusedOnDown) {
      _setFocusGated(true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.isSelectionMode) return;
    if (_pointerDownPos != null) {
      final delta = (event.position - _pointerDownPos!).distance;
      if (delta > 10.0) {
        _pointerScrolled = true;
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!widget.isSelectionMode) return;
    if (_isDraggingStartHandle || _isDraggingEndHandle) return;

    final selection = widget.controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    final duration = _pointerDownTime != null
        ? DateTime.now().difference(_pointerDownTime!).inMilliseconds
        : 0;

    if (hasSelection) {
      if (!_isTouchOnHandle(event.position) && !_pointerScrolled && duration < 300) {
        // Quick tap on selection clears selection
        debugPrint('[KB_LOG] PointerUp: Quick tap on selection -> clearing selection');
        _setFocusGated(false);
        widget.controller.selection = const TextSelection.collapsed(offset: 0);
      }
    } else {
      if (duration < 300 && !_pointerScrolled) {
        final rawOffset = _getGlobalOffsetFromPosition(event.position);
        final newSelection = TextSelection.collapsed(offset: rawOffset);

        if (_wasEditorFocusedOnDown) {
          // Mode 1 — Editor Already Focused:
          // Keep focus exactly as-is. Update selection/caret position only.
          // NO unfocus(), NO requestFocus(), NO TextInput.attach(), NO TextInput.close().
          debugPrint('[KB_LOG] PointerUp (Mode 1 - Editor Already Focused): Updating selection only, NO focus change');
          widget.controller.selection = newSelection;
        } else {
          // Mode 2 — Editor Not Focused:
          // Ungate focus and request focus for target segment to open keyboard.
          debugPrint('[KB_LOG] PointerUp (Mode 2 - Editor Not Focused): Ungating focus & requesting focus for segment');
          _setFocusGated(false);
          widget.controller.selection = newSelection;
          final sdeState = widget.sdeKey.currentState;
          if (sdeState != null) {
            for (final seg in sdeState.textSegments) {
              if (rawOffset >= seg.start && rawOffset <= seg.end) {
                debugPrint('[KB_LOG] requestFocus() on segment ${seg.segmentIndex}');
                sdeState.focusNodes[seg.segmentIndex]?.requestFocus();
                break;
              }
            }
          }
        }
      }
    }

    _pointerDownPos = null;
    _pointerDownTime = null;
    _pointerScrolled = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelectionMode) {
      return widget.child;
    }

    final selection = widget.controller.selection;
    final hasActiveSelection = selection.isValid && !selection.isCollapsed;
    final isDragging = _dragStartOffset != null ||
        _isDraggingStartHandle ||
        _isDraggingEndHandle;

    Offset? localMagnifierPos;
    if (isDragging && _lastCurrentPos != null) {
      final overlayRenderBox =
          _overlayKey.currentContext?.findRenderObject() as RenderBox?;
      if (overlayRenderBox != null && overlayRenderBox.hasSize) {
        localMagnifierPos = overlayRenderBox.globalToLocal(_lastCurrentPos!);
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (mounted && hasActiveSelection) {
          setState(() {});
        }
        return false;
      },
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        behavior: HitTestBehavior.translucent,
        child: RawGestureDetector(
          key: _overlayKey,
          gestures: {
            _LongPressDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                _LongPressDragGestureRecognizer>(
              () => _LongPressDragGestureRecognizer(),
              (_LongPressDragGestureRecognizer instance) {
                instance
                  ..isTouchOnHandle = _isTouchOnHandle
                  ..onLongPressDetected = _onLongPressDetected
                  ..onStart = _handlePanStart
                  ..onUpdate = _handlePanUpdate
                  ..onEnd = _handlePanEnd;
              },
            ),
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                foregroundPainter: _SDESelectionHighlightPainter(
                  controller: widget.controller,
                  sdeKey: widget.sdeKey,
                  overlayKey: _overlayKey,
                  onHandlePositionsUpdated: _updateHandlePositions,
                ),
                child: widget.child,
              ),
              if (isDragging && localMagnifierPos != null)
                Positioned(
                  left: localMagnifierPos.dx - 45,
                  top: localMagnifierPos.dy - 85,
                  child: IgnorePointer(
                    child: RawMagnifier(
                      size: const Size(90, 50),
                      magnificationScale: 1.25,
                      focalPointOffset: const Offset(0, 60),
                      decoration: MagnifierDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x3F000000),
                            blurRadius: 16,
                            offset: Offset(0, 0),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SDESelectionHighlightPainter extends CustomPainter {
  final RichTextEditingController controller;
  final GlobalKey<NewSingleDocumentEditorState> sdeKey;
  final GlobalKey overlayKey;
  final void Function(Offset? start, Offset? end)? onHandlePositionsUpdated;

  _SDESelectionHighlightPainter({
    required this.controller,
    required this.sdeKey,
    required this.overlayKey,
    this.onHandlePositionsUpdated,
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
    if (!selection.isValid || selection.isCollapsed) {
      onHandlePositionsUpdated?.call(null, null);
      return;
    }

    final sdeState = sdeKey.currentState;
    if (sdeState == null) {
      onHandlePositionsUpdated?.call(null, null);
      return;
    }

    final overlayRenderBox =
        overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayRenderBox == null || !overlayRenderBox.hasSize) {
      onHandlePositionsUpdated?.call(null, null);
      return;
    }

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

    Offset? startHandlePos;
    Offset? endHandlePos;

    for (final segment in sdeState.textSegments) {
      final segStart = segment.start;
      final segEnd = segment.end;

      if (selEnd >= segStart && selStart <= segEnd) {
        final containerKey = sdeState.segmentContainerKeys[segment.segmentIndex];
        final key = sdeState.textFieldKeys[segment.segmentIndex];
        final focusNode = sdeState.focusNodes[segment.segmentIndex];
        final context = containerKey?.currentContext ??
            key?.currentContext ??
            focusNode?.context;
        if (context == null) continue;

        final outerRenderBox = context.findRenderObject() as RenderBox?;
        if (outerRenderBox == null || !outerRenderBox.hasSize) continue;

        final renderEditable = _findRenderEditable(outerRenderBox);
        if (renderEditable == null ||
            renderEditable is! RenderBox ||
            !renderEditable.hasSize) {
          final lineTopLeft = overlayRenderBox
              .globalToLocal(outerRenderBox.localToGlobal(Offset.zero));
          final Rect rect = lineTopLeft & outerRenderBox.size;
          if (startHandlePos == null) {
            startHandlePos = Offset(rect.left, rect.bottom);
          }
          endHandlePos = Offset(rect.right, rect.bottom);
          continue;
        }

        final editableTopLeftInOverlay = overlayRenderBox
            .globalToLocal(renderEditable.localToGlobal(Offset.zero));

        final clampedStart = selStart.clamp(segStart, segEnd);
        final clampedEnd = selEnd.clamp(segStart, segEnd);

        final subController =
            sdeState.getSegmentController(segment.segmentIndex);
        final String displayedText = subController?.text ?? '';
        final int maxLen = displayedText.length;

        final localStartOffset = (clampedStart - segStart).clamp(0, maxLen);
        final localEndOffset = (clampedEnd - segStart).clamp(0, maxLen);
        final int effectiveEndOffset =
            localStartOffset == localEndOffset && maxLen > 0
                ? (localStartOffset + 1).clamp(0, maxLen)
                : localEndOffset;

        bool paintedBox = false;
        if (localStartOffset < effectiveEndOffset) {
          try {
            final dynamic editable = renderEditable;
            final TextSelection localSel = TextSelection(
              baseOffset: localStartOffset,
              extentOffset: effectiveEndOffset,
            );
            final List<TextBox> boxes =
                editable.getBoxesForSelection(localSel);

            if (boxes.isNotEmpty) {
              paintedBox = true;
              for (final box in boxes) {
                final Rect rect = Rect.fromLTRB(
                  editableTopLeftInOverlay.dx + box.left,
                  editableTopLeftInOverlay.dy + box.top,
                  editableTopLeftInOverlay.dx + box.right,
                  editableTopLeftInOverlay.dy + box.bottom,
                );
                final RRect rrect =
                    RRect.fromRectAndRadius(rect, const Radius.circular(3));
                canvas.drawRRect(rrect, paint);

                if (startHandlePos == null) {
                  startHandlePos = Offset(rect.left, rect.bottom);
                }
                endHandlePos = Offset(rect.right, rect.bottom);
              }
            }
          } catch (_) {}
        }

        if (!paintedBox) {
          final lineTopLeft = overlayRenderBox
              .globalToLocal(outerRenderBox.localToGlobal(Offset.zero));
          final Rect rect = lineTopLeft & outerRenderBox.size;
          if (startHandlePos == null) {
            startHandlePos = Offset(rect.left, rect.bottom);
          }
          endHandlePos = Offset(rect.right, rect.bottom);
        }
      }
    }

    // Paint contiguous selection highlights over non-text ImageSegments spanned by selection
    for (final docSegment in sdeState.allSegments) {
      if (docSegment is ImageSegment) {
        final imageKey = sdeState.imageKeys[docSegment.globalIndex];
        final imageContext = imageKey?.currentContext;
        if (imageContext != null) {
          final renderBox = imageContext.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            final localTopLeft = overlayRenderBox
                .globalToLocal(renderBox.localToGlobal(Offset.zero));
            final Rect imgRect = localTopLeft & renderBox.size;
            if (selStart <= docSegment.globalIndex &&
                selEnd >= docSegment.globalIndex) {
              final RRect rrect =
                  RRect.fromRectAndRadius(imgRect, const Radius.circular(8));
              canvas.drawRRect(rrect, paint);
            }
          }
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

    onHandlePositionsUpdated?.call(startHandlePos, endHandlePos);
  }

  @override
  bool shouldRepaint(covariant _SDESelectionHighlightPainter oldDelegate) {
    return true;
  }
}
