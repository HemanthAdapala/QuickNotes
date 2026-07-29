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
  bool _isDraggingSelection = false;

  static const String _sampleContent = '''# Multiline Drag Selection Test Page

This is paragraph 1 of the experimental test harness. You can drag your finger down across these lines to test multiline selection.

- [ ] Interactive checklist item 1
- [x] Completed checklist item 2
- [ ] Third checklist item for drag testing

> This is a blockquote section to test dragging selection across styled quote blocks.

Here is paragraph 2 with multiple words and formatting to verify seamless selection behavior across line boundaries without affecting NoteEditorScreen.
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
                onDragStateChanged: (isDragging) {
                  setState(() {
                    _isDraggingSelection = isDragging;
                  });
                },
                child: NewSingleDocumentEditor(
                  key: _sdeKey,
                  controller: _controller,
                  focusNode: _contentFocusNode,
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
