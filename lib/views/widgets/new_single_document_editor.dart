import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rich_text_controller.dart';
import 'new_image_widget.dart';
import '../../core/layout/layout_engine.dart';
import '../../core/layout/paragraph_block_behavior.dart';

abstract class DocSegment {
  final int globalIndex;
  DocSegment({required this.globalIndex});
}

class TextSegment extends DocSegment {
  final int segmentIndex;
  final String type; // 'paragraph', 'h1', 'h2', 'h3', 'quote', 'checkbox', 'bullet', 'number'
  final bool checked;
  final int indent;
  final int start;
  final int end;
  TextSegment({
    required super.globalIndex,
    required this.segmentIndex,
    required this.type,
    required this.start,
    required this.end,
    this.checked = false,
    this.indent = 0,
  });
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
  final double formattingToolbarHeight;
  final bool readOnly;
  final bool enableInteractiveSelection;
  final VoidCallback? onBackspaceAtStart;

  const NewSingleDocumentEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textColor,
    required this.paperGuideHeight,
    required this.contextMenuBuilder,
    required this.formattingToolbarHeight,
    this.readOnly = false,
    this.enableInteractiveSelection = true,
    this.onBackspaceAtStart,
  });

  @override
  State<NewSingleDocumentEditor> createState() => NewSingleDocumentEditorState();
}

class NewSingleDocumentEditorState extends State<NewSingleDocumentEditor> {
  List<DocSegment> _segments = [];
  final Map<int, RangeTextEditingController> _controllers = {};
  final Map<int, FocusNode> focusNodes = {};
  final Map<int, GlobalKey> _textFieldKeys = {};
  final Map<int, GlobalKey> _segmentContainerKeys = {};
  final Map<int, GlobalKey> _imageKeys = {};
  int? _selectedImageGlobalIndex;

  List<TextSegment> get textSegments => _segments.whereType<TextSegment>().toList();
  List<DocSegment> get allSegments => List.unmodifiable(_segments);
  Map<int, GlobalKey> get imageKeys => _imageKeys;
  Map<int, GlobalKey> get textFieldKeys => _textFieldKeys;
  Map<int, GlobalKey> get segmentContainerKeys => _segmentContainerKeys;
  RangeTextEditingController? getSegmentController(int segmentIndex) => _controllers[segmentIndex];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode.addListener(_onParentFocusChanged);
    parseCurrentSegments();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode.removeListener(_onParentFocusChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
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
      parseCurrentSegments();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onParentFocusChanged);
      widget.focusNode.addListener(_onParentFocusChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        parseCurrentSegments();
      });
      _syncFocusWithParentSelection();
    }
  }

  void focusFirstSegment() {
    if (focusNodes.isNotEmpty) {
      final minIndex = focusNodes.keys.reduce((a, b) => a < b ? a : b);
      focusNodes[minIndex]?.requestFocus();
    }
  }

  void _onParentFocusChanged() {
    if (widget.focusNode.hasFocus) {
      final alreadyFocused = focusNodes.values.any((n) => n.hasFocus);
      if (alreadyFocused) return;

      if (focusNodes.isNotEmpty) {
        final firstIndex = focusNodes.keys.reduce((a, b) => a < b ? a : b);
        focusNodes[firstIndex]?.requestFocus();
      }
    }
  }

  void _resizeImage(int globalIndex, double newWidth) {
    final chars = widget.controller.styledChars;
    if (globalIndex < chars.length) {
      final oldChar = chars[globalIndex];
      if (oldChar.char == '\uFFFC') {
        final newChar = StyledChar(
          char: oldChar.char,
          style: oldChar.style.copyWith(imageWidth: newWidth),
        );
        final List<StyledChar> updated = List.from(chars);
        updated[globalIndex] = newChar;

        widget.controller.styledChars = updated;
        widget.controller.value = TextEditingValue(
          text: updated.map((sc) => sc.char).join(),
          selection: widget.controller.selection,
        );
        widget.controller.notifyListeners();
        setState(() {});
      }
    }
  }

  void _deleteImage(int globalIndex) {
    final chars = widget.controller.styledChars;
    if (globalIndex < chars.length) {
      final oldChar = chars[globalIndex];
      if (oldChar.char == '\uFFFC') {
        final List<StyledChar> updated = List.from(chars);
        updated.removeAt(globalIndex);

        int deletionIdx = globalIndex;
        if (globalIndex > 0 && updated[globalIndex - 1].char == '\n') {
          updated.removeAt(globalIndex - 1);
          deletionIdx = globalIndex - 1;
        }

        widget.controller.saveUndoState();
        widget.controller.styledChars = updated;
        widget.controller.value = TextEditingValue(
          text: updated.map((sc) => sc.char).join(),
          selection: TextSelection.collapsed(offset: deletionIdx),
        );

        setState(() {
          _selectedImageGlobalIndex = null;
          parseCurrentSegments();
        });
      }
    }
  }

  void _syncFocusWithParentSelection() {
    if (_selectedImageGlobalIndex != null) return;
    final parentSel = widget.controller.selection;
    if (!parentSel.isValid) return;

    for (final segment in _segments.whereType<TextSegment>()) {
      final controller = _controllers[segment.segmentIndex];
      if (controller == null) continue;

      final range = controller.getRange();
      if (range.isValid && parentSel.baseOffset >= range.start && parentSel.baseOffset <= range.end) {
        final node = focusNodes[segment.segmentIndex];
        if (node != null && !node.hasFocus) {
          node.requestFocus();
        }
        break;
      }
    }
  }

  int _getPrefixOffset(String text) {
    final behavior = ParagraphBlockRegistry.getBehaviorForText(text);
    return behavior?.prefixLen ?? 0;
  }

  void _toggleCheckbox(TextSegment segment) {
    final chars = widget.controller.styledChars;
    if (segment.start < chars.length) {
      final oldChar = chars[segment.start];
      if (oldChar.char == '\u2610' || oldChar.char == '\u2611') {
        final bool newChecked = oldChar.char == '\u2610';
        final String newSymbol = newChecked ? '\u2611' : '\u2610';

        int lineEnd = segment.start;
        while (lineEnd < chars.length && chars[lineEnd].char != '\n') {
          lineEnd++;
        }

        final List<StyledChar> updated = List.from(chars);
        for (int i = segment.start; i < lineEnd; i++) {
          if (i < updated.length) {
            updated[i] = StyledChar(
              char: i == segment.start ? newSymbol : updated[i].char,
              style: updated[i].style.copyWith(
                checked: newChecked,
                strikethrough: newChecked,
              ),
            );
          }
        }

        widget.controller.saveUndoState();
        widget.controller.styledChars = updated;
        widget.controller.value = TextEditingValue(
          text: updated.map((sc) => sc.char).join(),
          selection: widget.controller.selection,
        );
      }
    }
  }

  void changeIndent(int segmentIndex, {required bool outdent}) {
    final controller = _controllers[segmentIndex];
    if (controller == null) return;

    final range = controller.getRange();
    if (!range.isValid) return;

    final chars = widget.controller.styledChars;
    final List<StyledChar> updated = List.from(chars);

    // Get current indent from the first character of this segment
    int currentIndent = 0;
    if (range.start < chars.length) {
      currentIndent = chars[range.start].style.indent;
    }

    int newIndent = outdent ? currentIndent - 1 : currentIndent + 1;
    if (newIndent < 0) newIndent = 0;
    if (newIndent > 5) newIndent = 5;

    if (newIndent != currentIndent) {
      // Update all characters in the current segment with the new indent level
      for (int i = range.start; i < range.end; i++) {
        if (i < updated.length) {
          updated[i] = StyledChar(
            char: updated[i].char,
            style: updated[i].style.copyWith(indent: newIndent),
          );
        }
      }

      widget.controller.saveUndoState();
      widget.controller.styledChars = updated;

      setState(() {
        parseCurrentSegments();
      });

      // Maintain selection
      widget.controller.value = TextEditingValue(
        text: updated.map((sc) => sc.char).join(),
        selection: widget.controller.selection,
      );
    }
  }

  KeyEventResult _handleEnterKey(int segmentIndex, RangeTextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return KeyEventResult.ignored;

    final behavior = ParagraphBlockRegistry.getBehaviorForText(text);
    if (behavior != null) {
      return behavior.handleEnterKey(
        segmentIndex: segmentIndex,
        controller: controller,
        editorState: this,
      );
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyEvent(int segmentIndex, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final controller = _controllers[segmentIndex];
    if (controller == null) return KeyEventResult.ignored;

    final selection = controller.selection;
    final text = controller.text;
    final prefixOffset = _getPrefixOffset(text);

    debugPrint("[SDE] _handleKeyEvent: segmentIndex=$segmentIndex, key=${event.logicalKey.keyLabel}, eventType=${event.runtimeType}, text='$text', selection=$selection");

    // Enter: Handle smart list/quote continuation or exit list/quote mode
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent) {
        return _handleEnterKey(segmentIndex, controller);
      }
    }

    // Tab / Shift + Tab: Indent / Outdent list items
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent) {
        final behavior = ParagraphBlockRegistry.getBehaviorForText(text);
        if (behavior != null) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          return behavior.handleTabKey(
            segmentIndex: segmentIndex,
            controller: controller,
            editorState: this,
            outdent: isShiftPressed,
          );
        }
      }
    }

    // Arrow Up / Left: Move to previous segment if cursor is at or before start of visible text
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset <= prefixOffset) {
        int prevIndex = segmentIndex - 1;
        while (prevIndex >= 0) {
          final prevController = _controllers[prevIndex];
          final prevNode = focusNodes[prevIndex];
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
          prevIndex--;
        }
      }
    }

    // Arrow Down / Right: Move to next segment if cursor is at the end of text
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset == text.length) {
        int nextIndex = segmentIndex + 1;
        while (nextIndex < _segments.length) {
          final nextController = _controllers[nextIndex];
          final nextNode = focusNodes[nextIndex];
          if (nextController != null && nextNode != null) {
            nextNode.requestFocus();
            final nextRange = nextController.getRange();
            if (nextRange.isValid) {
              final nextPrefixOffset = _getPrefixOffset(nextController.text);
              widget.controller.selection = TextSelection.collapsed(
                offset: nextRange.start + nextPrefixOffset,
              );
            }
            return KeyEventResult.handled;
          }
          nextIndex++;
        }
      }
    }

    // Backspace: Delete image if preceding is image, or merge with previous paragraph
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (selection.isValid && selection.isCollapsed && selection.baseOffset == prefixOffset) {
        if (event is KeyRepeatEvent) {
          return KeyEventResult.handled;
        }

        if (event is KeyDownEvent) {
          final behavior = ParagraphBlockRegistry.getBehaviorForText(text);

          // Case A: If it's a behavior item and cursor is at start (directly after prefix), delegate to behavior!
          if (behavior != null && text.length == 1) {
            return behavior.handleBackspaceKey(
              segmentIndex: segmentIndex,
              controller: controller,
              editorState: this,
            );
          }

          if (segmentIndex > 0) {
            final currentRange = controller.getRange();
            if (currentRange.isValid && currentRange.start > 0) {
              final imageIndex = currentRange.start - 1;
              final chars = widget.controller.styledChars;

              if (imageIndex < chars.length && chars[imageIndex].char == '\uFFFC') {
                final List<StyledChar> updatedChars = List.from(chars);
                updatedChars.removeAt(imageIndex);

                int deletionIndex = imageIndex;
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

              int prevIdx = segmentIndex - 1;
              while (prevIdx >= 0 && _controllers[prevIdx] == null) {
                prevIdx--;
              }
              final prevController = _controllers[prevIdx];
              final prevNode = focusNodes[prevIdx];
              if (prevController != null && prevNode != null) {
                widget.controller.saveUndoState();
                final prevRange = prevController.getRange();
                if (prevRange.isValid) {
                  final List<StyledChar> updatedChars = List.from(chars);
                  int newlineIndex = currentRange.start - 1;
                  
                  int charsToRemove = 1;
                  if (behavior != null) {
                    charsToRemove = 1 + behavior.prefixLen; // remove newline AND prefix characters!
                  }

                  if (newlineIndex >= 0 && newlineIndex + charsToRemove <= updatedChars.length) {
                    updatedChars.removeRange(newlineIndex, newlineIndex + charsToRemove);
                  }

                  widget.controller.styledChars = updatedChars;
                  widget.controller.value = TextEditingValue(
                    text: updatedChars.map((sc) => sc.char).join(),
                    selection: TextSelection.collapsed(offset: newlineIndex),
                  );

                  prevNode.requestFocus();
                  return KeyEventResult.handled;
                }
              }
            }
          }
        }
      }
    }

    return KeyEventResult.ignored;
  }

  TextSegment _createTextSegment(int start, int end, int segmentIndex) {
    final chars = widget.controller.styledChars;
    String type = 'paragraph';
    bool checked = false;
    int indent = 0;

    if (start < chars.length) {
      final style = chars[start].style;
      indent = style.indent;
      if (style.heading != 'normal') {
        type = style.heading;
      } else if (style.listType != 'normal') {
        type = style.listType;
        if (type == 'checkbox') {
          checked = chars[start].char == '\u2611';
        }
      }
    }

    return TextSegment(
      globalIndex: start,
      segmentIndex: segmentIndex,
      type: type,
      start: start,
      end: end,
      checked: checked,
      indent: indent,
    );
  }

  void parseCurrentSegments() {
    final chars = widget.controller.styledChars;
    final List<DocSegment> parsed = [];
    int textSegmentIndex = 0;

    int lineStart = 0;
    while (lineStart < chars.length) {
      int lineEnd = lineStart;
      while (lineEnd < chars.length && chars[lineEnd].char != '\n' && chars[lineEnd].char != '\uFFFC') {
        lineEnd++;
      }

      if (lineEnd < chars.length && chars[lineEnd].char == '\uFFFC' && chars[lineEnd].style.imageUrl != null) {
        if (lineEnd > lineStart) {
          parsed.add(_createTextSegment(lineStart, lineEnd, textSegmentIndex++));
        }
        parsed.add(ImageSegment(
          globalIndex: lineEnd,
          imageUrl: chars[lineEnd].style.imageUrl!,
          width: chars[lineEnd].style.imageWidth,
          caption: chars[lineEnd].style.imageCaption,
        ));
        if (lineEnd + 1 < chars.length && chars[lineEnd + 1].char == '\n') {
          lineStart = lineEnd + 2;
        } else {
          lineStart = lineEnd + 1;
        }
      } else {
        parsed.add(_createTextSegment(lineStart, lineEnd, textSegmentIndex++));
        lineStart = lineEnd + 1;
      }
    }

    if (chars.isEmpty || (chars.isNotEmpty && chars.last.char == '\n')) {
      parsed.add(TextSegment(
        globalIndex: chars.length,
        segmentIndex: textSegmentIndex,
        type: 'paragraph',
        start: chars.length,
        end: chars.length,
      ));
    }

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

    focusNodes.removeWhere((idx, node) {
      if (!activeTextIndices.contains(idx)) {
        node.dispose();
        return true;
      }
      return false;
    });

    _textFieldKeys.removeWhere((idx, key) => !activeTextIndices.contains(idx));
    _segmentContainerKeys.removeWhere((idx, key) => !activeTextIndices.contains(idx));

    final activeImageIndices = _segments
        .whereType<ImageSegment>()
        .map((s) => s.globalIndex)
        .toSet();
    _imageKeys.removeWhere((idx, key) => !activeImageIndices.contains(idx));

    for (final segment in _segments.whereType<TextSegment>()) {
      final node = focusNodes.putIfAbsent(
        segment.segmentIndex,
        () {
          final n = FocusNode();
          n.addListener(() {
            if (n.hasFocus && _selectedImageGlobalIndex != null) {
              setState(() {
                _selectedImageGlobalIndex = null;
              });
            }
          });
          n.onKeyEvent = (FocusNode node, KeyEvent event) {
            return _handleKeyEvent(segment.segmentIndex, node, event);
          };
          return n;
        },
      );
      
      final existingController = _controllers[segment.segmentIndex];
      if (existingController != null) {
        existingController.updateOffsets(segment.start, segment.end);
      }
      
      _controllers.putIfAbsent(
        segment.segmentIndex,
        () => RangeTextEditingController(
          parent: widget.controller,
          segmentIndex: segment.segmentIndex,
          focusNode: node,
          startOffset: segment.start,
          endOffset: segment.end,
        ),
      );
    }
  }

  int _getNumberedListIndex(TextSegment segment) {
    int index = 1;
    int segIdx = _segments.indexOf(segment);
    if (segIdx == -1) return 1;
    for (int i = segIdx - 1; i >= 0; i--) {
      final s = _segments[i];
      if (s is TextSegment && s.type == 'number') {
        index++;
      } else {
        break;
      }
    }
    return index;
  }

  Widget _buildTextSegmentWidget(TextSegment segment) {
    final controller = _controllers[segment.segmentIndex]!;
    final focusNode = focusNodes[segment.segmentIndex]!;
    final key = _textFieldKeys.putIfAbsent(segment.segmentIndex, () => GlobalKey());

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = keyboardInset + widget.formattingToolbarHeight + 30.0;

    double fontSize = 16.0;
    FontWeight fontWeight = FontWeight.normal;
    double lineHeight = 1.35;

    if (segment.type == 'h1') {
      fontSize = 24.0;
      fontWeight = FontWeight.bold;
      lineHeight = 1.2;
    } else if (segment.type == 'h2') {
      fontSize = 20.0;
      fontWeight = FontWeight.bold;
      lineHeight = 1.25;
    } else if (segment.type == 'h3') {
      fontSize = 18.0;
      fontWeight = FontWeight.bold;
      lineHeight = 1.3;
    }

    final textStyle = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: widget.textColor,
      height: lineHeight * widget.paperGuideHeight,
    );

    final textField = TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      readOnly: widget.readOnly,
      showCursor: !widget.readOnly,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      selectionControls: (!widget.enableInteractiveSelection) ? EmptyTextSelectionControls() : null,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      scrollPhysics: const NeverScrollableScrollPhysics(),
      scrollPadding: EdgeInsets.only(bottom: bottomPadding),
      contextMenuBuilder: widget.contextMenuBuilder,
      style: textStyle,
      textAlign: controller.lineAlignment,
      decoration: InputDecoration(
        hintText: segment.segmentIndex == 0 && controller.text.isEmpty
            ? "Start writing..."
            : null,
        hintStyle: GoogleFonts.inter(
          fontSize: fontSize,
          color: widget.textColor.withOpacity(0.3),
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        filled: false,
        isDense: true,
      ),
    );

    final textFieldWidget = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
          if (segment.segmentIndex == 0 && controller.selection.isCollapsed && controller.selection.start == 0) {
            if (widget.onBackspaceAtStart != null) {
              widget.onBackspaceAtStart!();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: textField,
    );

    final double firstLineHeight = fontSize * lineHeight * widget.paperGuideHeight;

    Widget resultWidget = textFieldWidget;

    if (segment.type == 'checkbox') {
      resultWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28.0,
            height: firstLineHeight,
            child: Align(
              alignment: const Alignment(-0.33, -0.22),
              child: InteractiveCheckbox(
                checked: segment.checked,
                onTap: () => _toggleCheckbox(segment),
                margin: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(child: textField),
        ],
      );
    } else if (segment.type == 'bullet') {
      resultWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28.0,
            height: firstLineHeight,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.textColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(child: textField),
        ],
      );
    } else if (segment.type == 'number') {
      resultWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 28.0,
            child: Text(
              "${_getNumberedListIndex(segment)}.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16.0,
                color: widget.textColor.withOpacity(0.5),
              ),
            ),
          ),
          Expanded(child: textField),
        ],
      );
    } else if (segment.type == 'quote') {
      resultWidget = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: widget.textColor.withOpacity(0.2),
              width: 3.0,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 12.0),
        child: textField,
      );
    }

    final containerKey = _segmentContainerKeys.putIfAbsent(segment.segmentIndex, () => GlobalKey());

    Widget finalWidget = resultWidget;
    if (segment.indent > 0) {
      finalWidget = Padding(
        padding: EdgeInsets.only(left: segment.indent * 24.0),
        child: resultWidget,
      );
    }

    return KeyedSubtree(
      key: containerKey,
      child: finalWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    for (int i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      Widget segmentWidget;

      if (segment is TextSegment) {
        segmentWidget = _buildTextSegmentWidget(segment);
      } else if (segment is ImageSegment) {
        final key = _imageKeys.putIfAbsent(segment.globalIndex, () => GlobalKey());
        segmentWidget = KeyedSubtree(
          key: key,
          child: NewImageWidget(
            imagePath: segment.imageUrl,
            width: segment.width,
            caption: segment.caption,
            isSelected: _selectedImageGlobalIndex == segment.globalIndex,
            onTap: () {
              setState(() {
                if (_selectedImageGlobalIndex == segment.globalIndex) {
                  _selectedImageGlobalIndex = null;
                } else {
                  _selectedImageGlobalIndex = segment.globalIndex;
                  for (final node in focusNodes.values) {
                    node.unfocus();
                  }
                  widget.controller.selection = TextSelection.collapsed(offset: segment.globalIndex);
                }
              });
            },
            onResize: (newWidth) => _resizeImage(segment.globalIndex, newWidth),
            onDelete: () => _deleteImage(segment.globalIndex),
          ),
        );
      } else {
        segmentWidget = const SizedBox.shrink();
      }

      children.add(segmentWidget);

      if (i < _segments.length - 1) {
        final nextSegment = _segments[i + 1];
        final String currentType = segment is ImageSegment ? 'image' : (segment as TextSegment).type;
        final String nextType = nextSegment is ImageSegment ? 'image' : (nextSegment as TextSegment).type;

        final double spacing = LayoutEngine.getSpacing(prevType: currentType, nextType: nextType);
        children.add(SizedBox(height: spacing));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void scrollToActiveSegment() {
    int? activeIdx;
    for (final entry in focusNodes.entries) {
      if (entry.value.hasFocus) {
        activeIdx = entry.key;
        break;
      }
    }
    if (activeIdx == null) return;

    final textKey = _textFieldKeys[activeIdx];
    final textContext = textKey?.currentContext;
    if (textContext == null) return;

    int? prevImageGlobalIdx;
    for (int i = _segments.length - 1; i >= 0; i--) {
      final seg = _segments[i];
      if (seg is TextSegment && seg.segmentIndex == activeIdx) {
        if (i > 0 && _segments[i - 1] is ImageSegment) {
          prevImageGlobalIdx = _segments[i - 1].globalIndex;
        }
        break;
      }
    }

    if (prevImageGlobalIdx != null) {
      final imgKey = _imageKeys[prevImageGlobalIdx];
      final imgContext = imgKey?.currentContext;
      if (imgContext != null) {
        Scrollable.ensureVisible(
          imgContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        ).then((_) {
          if (mounted) {
            final txtContext = _textFieldKeys[activeIdx]?.currentContext;
            if (txtContext != null) {
              Scrollable.ensureVisible(
                txtContext,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          }
        });
        return;
      }
    }

    Scrollable.ensureVisible(
      textContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }
}
