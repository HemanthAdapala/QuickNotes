import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/rich_text_controller.dart';
import '../../widgets/new_single_document_editor.dart';
import '../../widgets/experimental/single_document_drag_overlay.dart';

class SDEDragTestScreen extends StatefulWidget {
  const SDEDragTestScreen({super.key});

  @override
  State<SDEDragTestScreen> createState() => _SDEDragTestScreenState();
}

class _SDEDragTestScreenState extends State<SDEDragTestScreen> {
  late final RichTextEditingController _controller;
  final FocusNode _contentFocusNode = FocusNode();
  final GlobalKey<NewSingleDocumentEditorState> _sdeKey = GlobalKey<NewSingleDocumentEditorState>();
  final ScrollController _scrollController = ScrollController();
  bool _isDraggingSelection = false;
  bool _isSelectionMode = true;

  static const String _sampleContent = '''# Multiline Drag Selection Test Page

Welcome to the Single Document Editor multiline drag selection test environment. This document contains extended multiline content across various block types to allow thorough physical device testing.

## Section 1: Executive Overview

QuickNotes provides a seamless note-taking experience powered by a unified 4-tier reactive architecture. Single Document Editing allows users to construct documents containing rich typography, interactive checklists, formatted headings, and embedded media.

> "Simplicity is about subtracting the obvious and adding the meaningful." — John Maeda

## Section 2: Action Items & Tasks

Here is a list of project milestones for the upcoming sprint:

- [ ] Complete continuous drag selection overlay validation on physical devices
- [x] Integrate high-precision line boundary mapping for custom painters
- [ ] Verify keyboard suppression and touch gesture arena isolation
- [x] Ensure zero-disturbance guarantee for production NoteEditorScreen

## Section 3: Detailed Notes & Discussion

When writing long notes, maintaining smooth performance during continuous touch interactions is paramount. Touch gestures must be captured by dedicated eager gesture recognizers that resolve in favor of selection over scrolling.

1. First key requirement: Smooth cross-line text highlighting
2. Second key requirement: Zero keyboard interference during drag gestures
3. Third key requirement: Clean handle rendering at selection boundaries

### Section 3.1: Technical Architecture Highlights

The editor uses sub-controllers to manage local line representations while maintaining a single backing data source. Every change in text or selection is synchronized across reactive providers without mutating underlying models unsafely.

Paragraph blocks automatically format markdown prefixes into visual elements, enabling seamless bullet lists, numbered sequences, and checkable task items.

> Innovation distinguishes between a leader and a follower. Keep pushing the boundaries of mobile UX performance!

## Section 4: Concluding Summary

Dragging your finger across these paragraphs will highlight text across multiple lines simultaneously without bringing up the soft keyboard or jumping during scroll events.
''';

  @override
  void initState() {
    super.initState();
    _controller = RichTextEditingController();
    _controller.setMarkdown(_sampleContent);
    _controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _copySelectedText() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.text;
    final selStart = selection.start.clamp(0, text.length);
    final selEnd = selection.end.clamp(0, text.length);
    final selectedText = text.substring(selStart, selEnd);

    Clipboard.setData(ClipboardData(text: selectedText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Copied ${selectedText.length} characters to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cutSelectedText() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.text;
    final selStart = selection.start.clamp(0, text.length);
    final selEnd = selection.end.clamp(0, text.length);
    final selectedText = text.substring(selStart, selEnd);

    Clipboard.setData(ClipboardData(text: selectedText));

    final chars = List<StyledChar>.from(_controller.styledChars);
    chars.removeRange(selStart, selEnd);
    _controller.saveUndoState();
    _controller.styledChars = chars;
    _controller.selection = TextSelection.collapsed(offset: selStart);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✂️ Cut ${selectedText.length} characters'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearSelection() {
    _controller.selection = const TextSelection.collapsed(offset: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333);
    final hasSelection = _isSelectionMode &&
        _controller.selection.isValid &&
        !_controller.selection.isCollapsed;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🧪 SDE Drag Selection Test',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Sample Text',
            onPressed: () {
              setState(() {
                _controller.setMarkdown(_sampleContent);
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: hasSelection
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3F000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_controller.selection.end - _controller.selection.start).abs()} chars',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _copySelectedText,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _cutSelectedText,
                          icon: const Icon(Icons.content_cut_rounded, size: 18),
                          label: const Text('Cut'),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _clearSelection,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear Selection',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('✏️ Edit Mode'),
                          icon: Icon(Icons.edit_note_rounded),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('✨ Selection Mode'),
                          icon: Icon(Icons.select_all_rounded),
                        ),
                      ],
                      selected: {_isSelectionMode},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isSelectionMode = newSelection.first;
                          if (!_isSelectionMode) {
                            _clearSelection();
                          } else {
                            FocusManager.instance.primaryFocus?.unfocus();
                            SystemChannels.textInput.invokeMethod('TextInput.hide');
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: (_isSelectionMode && _isDraggingSelection)
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleDocumentDragOverlay(
                      controller: _controller,
                      sdeKey: _sdeKey,
                      scrollController: _scrollController,
                      isSelectionMode: _isSelectionMode,
                      onDragStateChanged: (isDragging) {
                        setState(() {
                          _isDraggingSelection = isDragging;
                        });
                      },
                      child: NewSingleDocumentEditor(
                        key: _sdeKey,
                        controller: _controller,
                        focusNode: _contentFocusNode,
                        readOnly: _isSelectionMode,
                        textColor: textColor,
                        paperGuideHeight: 1.0,
                        formattingToolbarHeight: 50.0,
                        contextMenuBuilder: (context, editableTextState) =>
                            AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: editableTextState.contextMenuButtonItems,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
