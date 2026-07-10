import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rich_text_controller.dart';
import 'new_image_widget.dart';

abstract class DocSegment {
  final int globalIndex;
  DocSegment({required this.globalIndex});
}

class TextSegment extends DocSegment {
  final int segmentIndex;
  TextSegment({required super.globalIndex, required this.segmentIndex});
}

class ImageSegment extends DocSegment {
  final String imageUrl;
  final double? width;
  final String? caption;
  ImageSegment({
    required super.globalIndex,
    required this.imageUrl,
    this.width,
    this.caption,
  });
}

class NewSingleDocumentEditor extends StatefulWidget {
  final RichTextEditingController controller;
  final FocusNode focusNode;
  final Color textColor;
  final double paperGuideHeight;
  final Widget Function(BuildContext, EditableTextState) contextMenuBuilder;

  const NewSingleDocumentEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textColor,
    required this.paperGuideHeight,
    required this.contextMenuBuilder,
  });

  @override
  State<NewSingleDocumentEditor> createState() => _NewSingleDocumentEditorState();
}

class _NewSingleDocumentEditorState extends State<NewSingleDocumentEditor> {
  List<DocSegment> _segments = [];
  final Map<int, RangeTextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode.addListener(_onParentFocusChanged);
    _parseCurrentSegments();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode.removeListener(_onParentFocusChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewSingleDocumentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _parseCurrentSegments();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onParentFocusChanged);
      widget.focusNode.addListener(_onParentFocusChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _parseCurrentSegments();
      });
      _syncFocusWithParentSelection();
    }
  }

  void _onParentFocusChanged() {
    if (widget.focusNode.hasFocus) {
      final alreadyFocused = _focusNodes.values.any((n) => n.hasFocus);
      if (alreadyFocused) return;

      _syncFocusWithParentSelection();

      final stillNotFocused = !_focusNodes.values.any((n) => n.hasFocus);
      if (stillNotFocused && _focusNodes.isNotEmpty) {
        final lastIndex = _focusNodes.keys.reduce((a, b) => a > b ? a : b);
        _focusNodes[lastIndex]?.requestFocus();
      }
    }
  }

  void _syncFocusWithParentSelection() {
    final parentSel = widget.controller.selection;
    if (!parentSel.isValid) return;

    for (final segment in _segments.whereType<TextSegment>()) {
      final controller = _controllers[segment.segmentIndex];
      if (controller == null) continue;

      final range = controller.getRange();
      if (range.isValid && parentSel.baseOffset >= range.start && parentSel.baseOffset <= range.end) {
        final node = _focusNodes[segment.segmentIndex];
        if (node != null && !node.hasFocus) {
          node.requestFocus();
        }
        break;
      }
    }
  }

  KeyEventResult _handleKeyEvent(int segmentIndex, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final controller = _controllers[segmentIndex];
    if (controller == null) return KeyEventResult.ignored;

    final selection = controller.selection;
    final text = controller.text;

    // Arrow Up / Left: Move to previous segment if cursor is at the start
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset == 0) {
        final prevSegmentIndex = segmentIndex - 1;
        final prevController = _controllers[prevSegmentIndex];
        final prevNode = _focusNodes[prevSegmentIndex];
        if (prevController != null && prevNode != null) {
          prevNode.requestFocus();
          final prevRange = prevController.getRange();
          if (prevRange.isValid) {
            widget.controller.selection = TextSelection.collapsed(
              offset: prevRange.start + prevController.text.length,
            );
          }
          return KeyEventResult.handled;
        }
      }
    }

    // Arrow Down / Right: Move to next segment if cursor is at the end
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset == text.length) {
        final nextSegmentIndex = segmentIndex + 1;
        final nextController = _controllers[nextSegmentIndex];
        final nextNode = _focusNodes[nextSegmentIndex];
        if (nextController != null && nextNode != null) {
          nextNode.requestFocus();
          final nextRange = nextController.getRange();
          if (nextRange.isValid) {
            widget.controller.selection = TextSelection.collapsed(
              offset: nextRange.start,
            );
          }
          return KeyEventResult.handled;
        }
      }
    }

    // Backspace: Delete image if cursor is at start of segment > 0
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset == 0 && segmentIndex > 0) {
        if (event is KeyRepeatEvent) {
          // Block repeated backspace deletion from deleting the image automatically
          return KeyEventResult.handled;
        }

        if (event is KeyDownEvent) {
          final currentRange = controller.getRange();
          if (currentRange.isValid && currentRange.start > 0) {
            final imageIndex = currentRange.start - 1;
            final chars = widget.controller.styledChars;
            if (imageIndex < chars.length && chars[imageIndex].char == '\uFFFC') {
              final List<StyledChar> updatedChars = List.from(chars);
              updatedChars.removeAt(imageIndex);

              int deletionIndex = imageIndex;
              // Also remove the preceding newline if there is one to merge the paragraphs cleanly
              if (imageIndex > 0 && updatedChars[imageIndex - 1].char == '\n') {
                updatedChars.removeAt(imageIndex - 1);
                deletionIndex = imageIndex - 1;
              }

              widget.controller.saveUndoState();
              widget.controller.styledChars = updatedChars;
              widget.controller.value = TextEditingValue(
                text: updatedChars.map((sc) => sc.char).join(),
                selection: TextSelection.collapsed(offset: deletionIndex),
              );
              return KeyEventResult.handled;
            }
          }
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _parseCurrentSegments() {
    final chars = widget.controller.styledChars;
    final List<DocSegment> parsed = [];
    int textSegmentIndex = 0;

    for (int i = 0; i < chars.length; i++) {
      final sc = chars[i];
      if (sc.char == '\uFFFC' && sc.style.imageUrl != null) {
        parsed.add(TextSegment(
          globalIndex: i,
          segmentIndex: textSegmentIndex,
        ));
        parsed.add(ImageSegment(
          globalIndex: i,
          imageUrl: sc.style.imageUrl!,
          width: sc.style.imageWidth,
          caption: sc.style.imageCaption,
        ));
        textSegmentIndex++;
      }
    }

    parsed.add(TextSegment(
      globalIndex: chars.length,
      segmentIndex: textSegmentIndex,
    ));

    _segments = parsed;

    final activeTextIndices = _segments
        .whereType<TextSegment>()
        .map((s) => s.segmentIndex)
        .toSet();

    _controllers.removeWhere((idx, controller) {
      if (!activeTextIndices.contains(idx)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    _focusNodes.removeWhere((idx, node) {
      if (!activeTextIndices.contains(idx)) {
        node.dispose();
        return true;
      }
      return false;
    });

    for (final segment in _segments.whereType<TextSegment>()) {
      _controllers.putIfAbsent(
        segment.segmentIndex,
        () => RangeTextEditingController(
          parent: widget.controller,
          segmentIndex: segment.segmentIndex,
        ),
      );
      _focusNodes.putIfAbsent(
        segment.segmentIndex,
        () {
          final node = FocusNode();
          node.onKeyEvent = (FocusNode n, KeyEvent event) {
            return _handleKeyEvent(segment.segmentIndex, n, event);
          };
          return node;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _segments.map((segment) {
        if (segment is TextSegment) {
          final controller = _controllers[segment.segmentIndex]!;
          final focusNode = _focusNodes[segment.segmentIndex]!;

          return TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            contextMenuBuilder: widget.contextMenuBuilder,
            style: GoogleFonts.inter(
              fontSize: 16.0,
              color: widget.textColor,
              height: 1.35 * widget.paperGuideHeight,
            ),
            decoration: InputDecoration(
              hintText: segment.segmentIndex == 0 && controller.text.isEmpty
                  ? "Start writing..."
                  : null,
              hintStyle: GoogleFonts.inter(
                fontSize: 16.0,
                color: widget.textColor.withOpacity(0.3),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
              isDense: true,
            ),
          );
        } else if (segment is ImageSegment) {
          return NewImageWidget(
            imagePath: segment.imageUrl,
            width: segment.width,
            caption: segment.caption,
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}
