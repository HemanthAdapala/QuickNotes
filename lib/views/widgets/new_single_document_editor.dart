import 'package:flutter/material.dart';
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
    }
  }

  void _onParentFocusChanged() {
    if (widget.focusNode.hasFocus) {
      if (_focusNodes.isNotEmpty) {
        final lastIndex = _focusNodes.keys.reduce((a, b) => a > b ? a : b);
        _focusNodes[lastIndex]?.requestFocus();
      }
    }
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
        () => FocusNode(),
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
