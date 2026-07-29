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
  }

  @override
  void dispose() {
    _controller.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF333333);

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
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: _isDraggingSelection
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded, color: Colors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Isolated Experimental Screen. Tap anywhere here to hide keyboard.',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        SystemChannels.textInput.invokeMethod('TextInput.hide');
                      },
                      icon: const Icon(Icons.keyboard_hide_rounded, size: 18),
                      label: const Text('Hide Keyboard'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleDocumentDragOverlay(
                controller: _controller,
                sdeKey: _sdeKey,
                scrollController: _scrollController,
                onDragStateChanged: (isDragging) {
                  setState(() {
                    _isDraggingSelection = isDragging;
                  });
                },
                child: NewSingleDocumentEditor(
                  key: _sdeKey,
                  controller: _controller,
                  focusNode: _contentFocusNode,
                  readOnly: true,
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
    );
  }
}
