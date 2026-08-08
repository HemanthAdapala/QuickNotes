import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../providers/notes_provider.dart';
import '../../services/vault_service.dart';
import '../widgets/folder_selection_sheet.dart';
import '../widgets/category_selection_sheet.dart';
import '../widgets/blurred_bottom_sheet.dart';
import '../widgets/rich_text_selection_toolbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/export_dialog.dart';
import '../widgets/rich_text_controller.dart';
import '../widgets/new_single_document_editor.dart';
import '../widgets/single_document_drag_overlay.dart';
import '../widgets/note_editor_options_popup.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/paper_guide_painters.dart';
import '../widgets/tactile_button.dart';
import '../widgets/rich_text_formatting_pill.dart';
import '../widgets/glass_container.dart';
import '../../themes/glassmorphism_presets.dart';
import 'package:flutter/services.dart';
import '../../core/animations/page_transitions.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/app_header_bar.dart';
import 'dart:math';
import 'dart:ui';


enum _ActiveCategory { none, aa, alignment, list, attachment, headings }

const bool kImageDebug = true;

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String defaultCategory;
  final String defaultNoteType;
  final String? defaultFolderId;
  static bool useSingleDocumentEditor = true;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.defaultCategory = 'Uncategorized',
    this.defaultNoteType = 'text',
    this.defaultFolderId,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _TitleTextEditingController extends TextEditingController {
  _TitleTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final cleanStyle = style?.copyWith(
      decoration: TextDecoration.none,
      fontStyle: FontStyle.normal,
    ) ?? const TextStyle(decoration: TextDecoration.none, fontStyle: FontStyle.normal);

    if (!value.composing.isValid || !withComposing) {
      return TextSpan(style: cleanStyle, text: text);
    }

    return TextSpan(
      style: cleanStyle,
      children: <TextSpan>[
        TextSpan(text: value.composing.textBefore(value.text)),
        TextSpan(
          style: cleanStyle,
          text: value.composing.textInside(value.text),
        ),
        TextSpan(text: value.composing.textAfter(value.text)),
      ],
    );
  }
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  final _titleController = _TitleTextEditingController();
  final _titleFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isMetadataCollapsed = false;
  bool _isKeyboardVisible = false;
  late final RichTextEditingController _contentController;
  final _tagController = TextEditingController();
  List<NoteBlock> _blocks = [];
  int _nextIdCounter = 0;
  NoteBlock? _lastFocusedBlock;
  bool _showDeletePopup = false;
  ResizableImageWidgetState? _activeDragImage;
  int _dragDirection = 0;
  Offset? _pointerDownPos;
  final GlobalKey<NewSingleDocumentEditorState> _sdeKey = GlobalKey<NewSingleDocumentEditorState>();

  String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randVal = random.nextInt(10000);
    return 'block_${timestamp}_${_nextIdCounter++}_$randVal';
  }

  List<NoteBlock> parseMarkdownToBlocks(String markdown) {
    final List<NoteBlock> blocks = [];
    if (markdown.trim().isEmpty) {
      final newBlock = ParagraphBlock(id: _generateId());
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
      blocks.add(newBlock);
      return blocks;
    }

    final lines = markdown.split('\n');
    
    bool isImageLine(String str) {
      final imageReg = RegExp(r'^!\[(.*?)\]\((.*?)\)$');
      return imageReg.hasMatch(str.trim());
    }

    ImageBlock parseImageBlock(String str) {
      final imageReg = RegExp(r'^!\[(.*?)\]\((.*?)\)$');
      final match = imageReg.firstMatch(str.trim())!;
      final alt = match.group(1);
      final url = match.group(2) ?? '';
      
      double? width;
      String cleanUrl = url;
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasQuery) {
        final wStr = uri.queryParameters['width'];
        if (wStr != null) width = double.tryParse(wStr);
        int qIdx = url.indexOf('?');
        if (qIdx != -1) {
          cleanUrl = url.substring(0, qIdx);
        }
      }
      return ImageBlock(
        id: _generateId(),
        imageUrl: cleanUrl,
        width: width,
        caption: (alt != null && alt.isNotEmpty && alt != 'Image') ? alt : null,
      );
    }

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Check if empty line
      if (trimmed.isEmpty) {
        final newBlock = ParagraphBlock(id: _generateId());
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if divider block
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(DividerBlock(id: _generateId()));
        i++;
        continue;
      }

      // Check if heading block
      if (trimmed.startsWith('# ')) {
        final newBlock = HeadingBlock(id: _generateId(), level: 1, markdown: trimmed.substring(2));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      } else if (trimmed.startsWith('## ')) {
        final newBlock = HeadingBlock(id: _generateId(), level: 2, markdown: trimmed.substring(3));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      } else if (trimmed.startsWith('### ')) {
        final newBlock = HeadingBlock(id: _generateId(), level: 3, markdown: trimmed.substring(4));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if quote block
      if (trimmed.startsWith('> ')) {
        final newBlock = QuoteBlock(id: _generateId(), markdown: trimmed.substring(2));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if checklist block
      if (trimmed.startsWith('- [ ] ')) {
        final newBlock = ChecklistBlock(id: _generateId(), isChecked: false, markdown: trimmed.substring(6));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
        final newBlock = ChecklistBlock(id: _generateId(), isChecked: true, markdown: trimmed.substring(6));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if bulleted list block
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('+ ')) {
        final newBlock = BulletedListBlock(id: _generateId(), markdown: trimmed.substring(2));
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if numbered list block
      final numListRegex = RegExp(r'^(\d+)\.\s(.*)$');
      if (numListRegex.hasMatch(trimmed)) {
        final match = numListRegex.firstMatch(trimmed)!;
        final content = match.group(2) ?? '';
        final newBlock = NumberedListBlock(id: _generateId(), markdown: content);
        _setupBlockFocusNode(newBlock.focusNode);
        _setupBlockController(newBlock);
        blocks.add(newBlock);
        i++;
        continue;
      }

      // Check if consecutive image blocks
      if (isImageLine(trimmed)) {
        final List<ImageBlock> images = [];
        images.add(parseImageBlock(trimmed));
        i++;
        while (i < lines.length && isImageLine(lines[i])) {
          images.add(parseImageBlock(lines[i]));
          i++;
        }
        if (images.length == 1) {
          blocks.add(images[0]);
        } else {
          blocks.add(ImageStackBlock(id: _generateId(), images: images));
        }
        continue;
      }

      // Default to ParagraphBlock
      final newBlock = ParagraphBlock(id: _generateId(), markdown: line);
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
      blocks.add(newBlock);
      i++;
    }

    if (blocks.isEmpty) {
      final newBlock = ParagraphBlock(id: _generateId());
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
      blocks.add(newBlock);
    }
    return blocks;
  }

  void _setupBlockFocusNode(FocusNode focusNode) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (!_isFormattingBarExpanded) {
          setState(() {
            _isFormattingBarExpanded = true;
          });
        }
        for (final block in _blocks) {
          if (_getFocusNodeOfBlock(block) == focusNode) {
            _lastFocusedBlock = block;
            break;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.context != null) {
            Scrollable.ensureVisible(
              focusNode.context!,
              alignment: 0.1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_anyBlockHasFocus && _isMetadataCollapsed) {
            setState(() {
              _isMetadataCollapsed = false;
            });
          }
        });
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setupBlockController(NoteBlock block) {
    final controller = _getControllerOfBlock(block);
    if (controller is RichTextEditingController) {
      controller.onStyleChanged = () {
        if (mounted) setState(() {});
      };
      controller.onReplaceImage = _showReplaceGalleryBottomSheet;
    }
  }

  RichTextEditingController? _getControllerOfBlock(NoteBlock block) {
    if (block is ParagraphBlock) return block.controller;
    if (block is HeadingBlock) return block.controller;
    if (block is QuoteBlock) return block.controller;
    if (block is ChecklistBlock) return block.controller;
    if (block is BulletedListBlock) return block.controller;
    if (block is NumberedListBlock) return block.controller;
    return null;
  }

  FocusNode? _getFocusNodeOfBlock(NoteBlock block) {
    if (block is ParagraphBlock) return block.focusNode;
    if (block is HeadingBlock) return block.focusNode;
    if (block is QuoteBlock) return block.focusNode;
    if (block is ChecklistBlock) return block.focusNode;
    if (block is BulletedListBlock) return block.focusNode;
    if (block is NumberedListBlock) return block.focusNode;
    return null;
  }

  int _getNumberedIndex(NoteBlock block) {
    int index = 1;
    final blockIdx = _blocks.indexOf(block);
    if (blockIdx == -1) return 1;
    for (int i = blockIdx - 1; i >= 0; i--) {
      if (_blocks[i] is NumberedListBlock) {
        index++;
      } else {
        break;
      }
    }
    return index;
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.offset < 5.0 && _isMetadataCollapsed) {
      setState(() {
        _isMetadataCollapsed = false;
      });
    }
  }

  void _onBlockTextChanged(NoteBlock block) {
    if (!_isMetadataCollapsed) {
      setState(() {
        _isMetadataCollapsed = true;
      });
    }
    if (_activeCategory != _ActiveCategory.none && !Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        _activeCategory = _ActiveCategory.none;
      });
    }
    _startZenTimer();
    final controller = _getControllerOfBlock(block);
    if (controller == null) return;

    final text = controller.text;
    if (text.contains('\n')) {
      final index = _blocks.indexOf(block);
      if (index == -1) return;

      final lines = text.split('\n');
      
      int currentOffset = 0;
      final List<List<StyledChar>> linesStyledChars = [];
      for (final line in lines) {
        final lineChars = controller.styledChars
            .skip(currentOffset)
            .take(line.length)
            .toList();
        linesStyledChars.add(lineChars);
        currentOffset += line.length + 1; // plus 1 for the '\n'
      }

      // Update current block
      controller.text = lines[0];
      controller.styledChars = linesStyledChars[0];

      // Create new blocks for the remaining lines
      final List<NoteBlock> newBlocks = [];
      for (int i = 1; i < lines.length; i++) {
        NoteBlock newBlock;
        if (block is ChecklistBlock) {
          newBlock = ChecklistBlock(id: _generateId(), isChecked: false);
        } else if (block is BulletedListBlock) {
          newBlock = BulletedListBlock(id: _generateId());
        } else if (block is NumberedListBlock) {
          newBlock = NumberedListBlock(id: _generateId());
        } else if (block is QuoteBlock) {
          newBlock = QuoteBlock(id: _generateId());
        } else {
          newBlock = ParagraphBlock(id: _generateId());
        }
        
        _setupBlockFocusNode(_getFocusNodeOfBlock(newBlock)!);
        _setupBlockController(newBlock);

        final newBlockController = _getControllerOfBlock(newBlock);
        if (newBlockController != null) {
          newBlockController.text = lines[i];
          newBlockController.styledChars = linesStyledChars[i];
        }
        newBlocks.add(newBlock);
      }

      setState(() {
        _blocks.insertAll(index + 1, newBlocks);
        _hasChanges = true;
      });

      // Focus the new block right after the current one
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstNewBlock = newBlocks.first;
        final fn = _getFocusNodeOfBlock(firstNewBlock);
        final ctrl = _getControllerOfBlock(firstNewBlock);
        if (fn != null && ctrl != null) {
          fn.requestFocus();
          ctrl.selection = const TextSelection.collapsed(offset: 0);
        }
      });
    } else {
      _calculateCounts();
      _startZenTimer();
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _handleEnterKey(NoteBlock block) {
    final index = _blocks.indexOf(block);
    if (index == -1) return;

    final controller = _getControllerOfBlock(block);
    if (controller == null) return;

    if ((block is ChecklistBlock || block is BulletedListBlock || block is NumberedListBlock) && controller.text.isEmpty) {
      _toggleBlockType(block, ParagraphBlock);
      return;
    }

    final selection = controller.selection;
    final text = controller.text;
    final styledChars = controller.styledChars;

    int cursor = selection.isValid ? selection.start : text.length;
    cursor = cursor.clamp(0, text.length);

    final textBefore = text.substring(0, cursor);
    final textAfter = text.substring(cursor);
    final charsBefore = styledChars.take(cursor).toList();
    final charsAfter = styledChars.skip(cursor).toList();

    // Update current block
    controller.text = textBefore;
    controller.styledChars = charsBefore;

    // Create new block
    NoteBlock newBlock;
    if (block is ChecklistBlock) {
      newBlock = ChecklistBlock(id: _generateId(), isChecked: false);
    } else if (block is BulletedListBlock) {
      newBlock = BulletedListBlock(id: _generateId());
    } else if (block is NumberedListBlock) {
      newBlock = NumberedListBlock(id: _generateId());
    } else if (block is QuoteBlock) {
      newBlock = QuoteBlock(id: _generateId());
    } else {
      newBlock = ParagraphBlock(id: _generateId());
    }

    _setupBlockFocusNode(_getFocusNodeOfBlock(newBlock)!);
    _setupBlockController(newBlock);

    final newBlockController = _getControllerOfBlock(newBlock);
    if (newBlockController != null) {
      newBlockController.text = textAfter;
      newBlockController.styledChars = charsAfter;
    }

    setState(() {
      _blocks.insert(index + 1, newBlock);
      _hasChanges = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fn = _getFocusNodeOfBlock(newBlock);
      final ctrl = _getControllerOfBlock(newBlock);
      if (fn != null && ctrl != null) {
        fn.requestFocus();
        ctrl.selection = const TextSelection.collapsed(offset: 0);
      }
    });
  }

  void _handleBackspaceAtStart(NoteBlock block) {
    final ctrl = _getControllerOfBlock(block);
    if ((block is ChecklistBlock || block is BulletedListBlock || block is NumberedListBlock) && ctrl != null && ctrl.text.isEmpty) {
      _toggleBlockType(block, ParagraphBlock);
      return;
    }

    final index = _blocks.indexOf(block);
    if (index <= 0) return;

    final prevBlock = _blocks[index - 1];

    if (prevBlock is ImageBlock || prevBlock is ImageStackBlock || prevBlock is DividerBlock) {
      // Delete the image/divider/stack block
      setState(() {
        _blocks.removeAt(index - 1);
        _hasChanges = true;
      });
    } else {
      // It's a text-based block. Merge!
      final currentController = _getControllerOfBlock(block);
      final prevController = _getControllerOfBlock(prevBlock);
      if (currentController != null && prevController != null) {
        final prevLength = prevController.text.length;
        final mergedStyledChars = List<StyledChar>.from(prevController.styledChars)
          ..addAll(currentController.styledChars);
        final mergedText = prevController.text + currentController.text;

        setState(() {
          prevController.styledChars = mergedStyledChars;
          prevController.text = mergedText;
          _blocks.removeAt(index);
          _hasChanges = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final prevFocusNode = _getFocusNodeOfBlock(prevBlock);
          if (prevFocusNode != null) {
            prevFocusNode.requestFocus();
            prevController.selection = TextSelection.collapsed(offset: prevLength);
          }
        });
      }
    }
  }

  void _handleArrowUpAtStart(NoteBlock block) {
    final index = _blocks.indexOf(block);
    if (index <= 0) return;

    for (int i = index - 1; i >= 0; i--) {
      final b = _blocks[i];
      final fn = _getFocusNodeOfBlock(b);
      final ctrl = _getControllerOfBlock(b);
      if (fn != null && ctrl != null) {
        fn.requestFocus();
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        break;
      }
    }
  }

  void _focusContentArea() {
    if (!mounted) return;
    if (NoteEditorScreen.useSingleDocumentEditor) {
      final sdeState = _sdeKey.currentState;
      if (sdeState != null) {
        sdeState.focusFirstSegment();
      } else {
        _contentFocusNode.requestFocus();
      }
      if (_contentController.selection.start < 0) {
        _contentController.selection = const TextSelection.collapsed(offset: 0);
      }
    } else if (_blocks.isNotEmpty) {
      final firstBlock = _blocks.first;
      final fn = _getFocusNodeOfBlock(firstBlock);
      final ctrl = _getControllerOfBlock(firstBlock);
      if (fn != null) {
        fn.requestFocus();
        if (ctrl != null && ctrl.selection.start < 0) {
          ctrl.selection = const TextSelection.collapsed(offset: 0);
        }
      }
    }
  }

  void _handleArrowDownAtEnd(NoteBlock block) {
    final index = _blocks.indexOf(block);
    if (index == -1 || index >= _blocks.length - 1) return;

    for (int i = index + 1; i < _blocks.length; i++) {
      final b = _blocks[i];
      final fn = _getFocusNodeOfBlock(b);
      final ctrl = _getControllerOfBlock(b);
      if (fn != null && ctrl != null) {
        fn.requestFocus();
        ctrl.selection = const TextSelection.collapsed(offset: 0);
        break;
      }
    }
  }


  void _insertParagraphAt(int index) {
    if (index > 0 && index - 1 < _blocks.length) {
      final prevBlock = _blocks[index - 1];
      if (prevBlock is ParagraphBlock && prevBlock.controller.text.isEmpty) {
        prevBlock.focusNode.requestFocus();
        return;
      }
    }
    if (index < _blocks.length) {
      final nextBlock = _blocks[index];
      if (nextBlock is ParagraphBlock && nextBlock.controller.text.isEmpty) {
        nextBlock.focusNode.requestFocus();
        return;
      }
    }

    final newBlock = ParagraphBlock(id: _generateId());
    _setupBlockFocusNode(newBlock.focusNode);
    _setupBlockController(newBlock);
    
    setState(() {
      _blocks.insert(index, newBlock);
      _hasChanges = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      newBlock.focusNode.requestFocus();
    });
  }

  double _getSpacingBetween(NoteBlock current, NoteBlock next) {
    // Heading ↔ Paragraph/Text/Checklist: 4px spacing
    if (current is HeadingBlock && (next is ParagraphBlock || next is QuoteBlock || next is ChecklistBlock)) {
      return 4.0;
    }
    if ((current is ParagraphBlock || current is QuoteBlock || current is ChecklistBlock) && next is HeadingBlock) {
      return 4.0;
    }

    final isCurrentMedia = current is ImageBlock || current is ImageStackBlock;
    final isNextMedia = next is ImageBlock || next is ImageStackBlock;

    // Image ↔ Paragraph/Text/Checklist: 6px spacing
    if ((isCurrentMedia && (next is ParagraphBlock || next is QuoteBlock || next is ChecklistBlock)) ||
        ((current is ParagraphBlock || current is QuoteBlock || current is ChecklistBlock) && isNextMedia)) {
      return 6.0;
    }

    // Paragraph ↔ Paragraph: 2px spacing
    if ((current is ParagraphBlock || current is QuoteBlock) && (next is ParagraphBlock || next is QuoteBlock)) {
      return 2.0;
    }

    // Checklist ↔ Checklist: 2px spacing
    if (current is ChecklistBlock && next is ChecklistBlock) {
      return 2.0;
    }

    // Media ↔ Media: 6px spacing
    if (isCurrentMedia && isNextMedia) {
      return 6.0;
    }

    if (current is DividerBlock || next is DividerBlock) {
      return 6.0;
    }

    return 2.0;
  }

  Color _getPaperGuideColor(bool isDark) {
    if (_paperGuideColor == 0) {
      return isDark ? Colors.white : Colors.black;
    }
    return Color(_paperGuideColor);
  }

  Widget _wrapWithBlockPaperGuide(Widget blockWidget, {NoteBlock? block, bool isBottomSpacer = false}) {
    if (block == null && !isBottomSpacer) return blockWidget;
    if (block != null &&
        block is! ParagraphBlock &&
        block is! HeadingBlock &&
        block is! ChecklistBlock &&
        block is! QuoteBlock) {
      return blockWidget;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLines = _paperGuideType.startsWith('lines') || _paperGuideType == 'custom';
    final showLines = _paperGuideVisible && isLines;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: showLines
                  ? CustomPaint(
                      key: ValueKey('${_paperGuideType}_${_paperGuideColor}_${_paperGuideOpacity}'),
                      painter: BlockPaperGuidePainter(
                        guideType: _paperGuideType,
                        lineHeight: 20.0 * _paperGuideHeight,
                        color: _getPaperGuideColor(isDark),
                        opacity: _paperGuideOpacity,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty_block_guide')),
            ),
          ),
        ),
        blockWidget,
      ],
    );
  }

  Widget _buildBlockWidget(NoteBlock block, Color textColor, Color titleColor) {
    final rawWidget = _buildRawBlockWidget(block, textColor, titleColor);
    final blockWidget = _wrapWithBlockPaperGuide(rawWidget, block: block);

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        print('DRAG_DEBUG: onWillAcceptWithDetails for target block = ${block.id} (type: ${block.runtimeType}), data = ${details.data}');
        return details.data['imagePath'] != null;
      },
      onLeave: (data) {
        print('DRAG_DEBUG: onLeave for target block = ${block.id} (type: ${block.runtimeType}), data = $data');
      },
      onAcceptWithDetails: (details) {
        print('DRAG_DEBUG: onAcceptWithDetails for target block = ${block.id} (type: ${block.runtimeType}), data = ${details.data}');
        final data = details.data;
        final oldIndex = data['oldIndex'] as int;
        final stackImgIdx = data['stackImageIndex'] as int?;
        final targetIndex = _blocks.indexOf(block);
        if (targetIndex == -1) return;
        if (oldIndex == targetIndex) return;

        setState(() {
          // 1. Get the dragged ImageBlock
          ImageBlock draggedImgBlock;
          if (stackImgIdx != null) {
            final sourceStack = _blocks[oldIndex] as ImageStackBlock;
            draggedImgBlock = sourceStack.images[stackImgIdx];
            sourceStack.images.removeAt(stackImgIdx);
            if (sourceStack.images.length == 1) {
              _blocks[oldIndex] = sourceStack.images[0];
            }
          } else {
            draggedImgBlock = _blocks[oldIndex] as ImageBlock;
            _blocks.removeAt(oldIndex);
          }

          // 2. Adjust targetIndex
          int adjustedTargetIndex = _blocks.indexOf(block);
          if (adjustedTargetIndex == -1) {
            adjustedTargetIndex = targetIndex.clamp(0, _blocks.length);
          }

          // 3. Merge or insert
          final resolvedTargetBlock = _blocks[adjustedTargetIndex];
          if (resolvedTargetBlock is ImageBlock) {
            final stack = ImageStackBlock(
              id: _generateId(),
              images: [resolvedTargetBlock, draggedImgBlock],
            );
            _blocks[adjustedTargetIndex] = stack;
          } else if (resolvedTargetBlock is ImageStackBlock) {
            resolvedTargetBlock.images.add(draggedImgBlock);
          } else {
            _blocks.insert(adjustedTargetIndex, draggedImgBlock);
          }
          _hasChanges = true;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final isImage = block is ImageBlock || block is ImageStackBlock;
        
        if (isHovered && isImage) {
          return Stack(
            children: [
              blockWidget,
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2.0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return blockWidget;
      },
    );
  }

  Widget _buildRawBlockWidget(NoteBlock block, Color textColor, Color titleColor) {
    if (block is ParagraphBlock) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
              _handleEnterKey(block);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == 0) {
                _handleBackspaceAtStart(block);
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == 0) {
                _handleArrowUpAtStart(block);
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == block.controller.text.length) {
                _handleArrowDownAtEnd(block);
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          contextMenuBuilder: _buildContextMenu,
          scrollPadding: EdgeInsets.only(bottom: _getDynamicBottomScrollPadding()),
          textAlign: block.controller.styledChars.isNotEmpty
              ? block.controller.styledChars.first.style.align
              : block.controller.currentActiveStyle.align,
          style: GoogleFonts.inter(
            fontSize: 16.0,
            color: textColor,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: _blocks.indexOf(block) == 0 && _blocks.length == 1 ? "Start writing..." : "",
            hintStyle: GoogleFonts.inter(
              fontSize: 16.0,
              color: textColor.withAlpha(80),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            filled: false,
            isDense: true,
          ),
          onChanged: (val) => _onBlockTextChanged(block),
        ),
      );
    }

    if (block is HeadingBlock) {
      double fontSize = 20.0;
      if (block.level == 1) {
        fontSize = 28.0;
      } else if (block.level == 2) {
        fontSize = 24.0;
      } else if (block.level == 3) {
        fontSize = 22.0;
      }

      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
              _handleEnterKey(block);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == 0) {
                _handleBackspaceAtStart(block);
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == 0) {
                _handleArrowUpAtStart(block);
                return KeyEventResult.handled;
              }
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final sel = block.controller.selection;
              if (sel.isCollapsed && sel.start == block.controller.text.length) {
                _handleArrowDownAtEnd(block);
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          contextMenuBuilder: _buildContextMenu,
          scrollPadding: EdgeInsets.only(bottom: _getDynamicBottomScrollPadding()),
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: titleColor,
            height: _paperGuideHeight,
          ),
          decoration: InputDecoration(
            hintText: "Heading ${block.level}",
            hintStyle: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: titleColor.withAlpha(80),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            filled: false,
            isDense: true,
          ),
          onChanged: (val) => _onBlockTextChanged(block),
        ),
      );
    }

    if (block is QuoteBlock) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: titleColor.withAlpha(100),
              width: 4.0,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 12.0),
        margin: EdgeInsets.zero,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                _handleEnterKey(block);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.backspace) {
                final sel = block.controller.selection;
                if (sel.isCollapsed && sel.start == 0) {
                  _handleBackspaceAtStart(block);
                  return KeyEventResult.handled;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                final sel = block.controller.selection;
                if (sel.isCollapsed && sel.start == 0) {
                  _handleArrowUpAtStart(block);
                  return KeyEventResult.handled;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                final sel = block.controller.selection;
                if (sel.isCollapsed && sel.start == block.controller.text.length) {
                  _handleArrowDownAtEnd(block);
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: block.controller,
            focusNode: block.focusNode,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            contextMenuBuilder: _buildContextMenu,
            scrollPadding: EdgeInsets.only(bottom: _getDynamicBottomScrollPadding()),
            style: GoogleFonts.inter(
              fontSize: 16.0,
              color: textColor.withAlpha(220),
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: "Quote",
              hintStyle: GoogleFonts.inter(
                fontSize: 16.0,
                color: textColor.withAlpha(80),
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
              isDense: true,
            ),
            onChanged: (val) => _onBlockTextChanged(block),
          ),
        ),
      );
    }

    if (block is ChecklistBlock) {
      return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  block.isChecked = !block.isChecked;
                  _hasChanges = true;
                  _calculateCounts();
                });
              },
              child: Container(
                margin: const EdgeInsets.only(top: 6.0, right: 8.0, left: 4.0),
                width: 10,
                height: 10,
                decoration: block.isChecked
                    ? const BoxDecoration(color: Color(0xFF222222))
                    : BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
                child: block.isChecked
                    ? Center(
                        child: SvgPicture.asset(
                          'assets/icons/vector_check.svg',
                          width: 6,
                          height: 6,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                      _handleEnterKey(block);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.backspace) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleBackspaceAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleArrowUpAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == block.controller.text.length) {
                        _handleArrowDownAtEnd(block);
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: block.controller,
                  focusNode: block.focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  contextMenuBuilder: _buildContextMenu,
                  scrollPadding: const EdgeInsets.only(bottom: 90.0),
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    color: block.isChecked ? textColor.withAlpha(120) : textColor,
                    decoration: block.isChecked ? TextDecoration.lineThrough : null,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    hintText: "To-do item",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    isDense: true,
                  ),
                  onChanged: (val) => _onBlockTextChanged(block),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block is BulletedListBlock) {
      return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8.0, right: 10.0, left: 6.0),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                      _handleEnterKey(block);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.backspace) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleBackspaceAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleArrowUpAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == block.controller.text.length) {
                        _handleArrowDownAtEnd(block);
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: block.controller,
                  focusNode: block.focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  contextMenuBuilder: _buildContextMenu,
                  scrollPadding: const EdgeInsets.only(bottom: 90.0),
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    color: textColor,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    hintText: "List item",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    isDense: true,
                  ),
                  onChanged: (val) => _onBlockTextChanged(block),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block is NumberedListBlock) {
      final num = _getNumberedIndex(block);
      return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 0.0, right: 8.0, left: 4.0),
              width: 18,
              alignment: Alignment.topRight,
              child: Text(
                "$num.",
                style: GoogleFonts.inter(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                      _handleEnterKey(block);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.backspace) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleBackspaceAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == 0) {
                        _handleArrowUpAtStart(block);
                        return KeyEventResult.handled;
                      }
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final sel = block.controller.selection;
                      if (sel.isCollapsed && sel.start == block.controller.text.length) {
                        _handleArrowDownAtEnd(block);
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: block.controller,
                  focusNode: block.focusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  contextMenuBuilder: _buildContextMenu,
                  scrollPadding: const EdgeInsets.only(bottom: 90.0),
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    color: textColor,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    hintText: "List item",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    isDense: true,
                  ),
                  onChanged: (val) => _onBlockTextChanged(block),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block is ImageBlock) {
      return ResizableImageWidget(
        imagePath: block.imageUrl,
        initialWidth: block.width,
        caption: block.caption,
        index: _blocks.indexOf(block),
        onUpdate: (newWidth, newCaption) {
          setState(() {
            block.width = newWidth;
            block.caption = newCaption;
            _hasChanges = true;
          });
        },
        onDelete: () {
          setState(() {
            _blocks.remove(block);
            _hasChanges = true;
          });
        },
        onReplace: () => _showReplaceGalleryBottomSheet(_blocks.indexOf(block)),
      );
    }

    if (block is ImageStackBlock) {
      return ImageStackWidget(
        block: block,
        textColor: textColor,
        titleColor: titleColor,
        index: _blocks.indexOf(block),
        onUpdate: () {
          setState(() {
            _hasChanges = true;
          });
        },
        onDeleteImage: (imgBlock) {
          setState(() {
            block.images.remove(imgBlock);
            if (block.images.isEmpty) {
              _blocks.remove(block);
            } else if (block.images.length == 1) {
              final idx = _blocks.indexOf(block);
              if (idx != -1) {
                _blocks[idx] = block.images[0];
              }
            }
            _hasChanges = true;
          });
        },
        onReplaceImage: (imgBlock, stackImageIndex) {
          _showReplaceGalleryBottomSheet(
            _blocks.indexOf(block),
            stackImageIndex: stackImageIndex,
          );
        },
      );
    }

    if (block is DividerBlock) {
      return Container(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: textColor.withAlpha(40),
                thickness: 1.5,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: () {
                setState(() {
                  _blocks.remove(block);
                  _hasChanges = true;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  final _contentFocusNode = FocusNode();
  final _pageController = PageController(initialPage: 1);
  int _currentPage = 1;
  bool _wasSelectionActive = false;
  
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  bool _isNoteOptionsOpen = false;
  String _category = 'Uncategorized';
  String _noteType = 'text'; // 'text' or 'checklist' (migration)
  bool _isLocked = false;
  DateTime? _reminderTime;

  List<String> _tags = [];
  List<Map<String, dynamic>> _attachments = [];
  final List<Map<String, dynamic>> _checklistItems = const []; // legacy removed
  final List<TextEditingController> _checklistControllers = const []; // legacy removed
  final List<FocusNode> _checklistFocusNodes = const []; // legacy removed

  // Folders & Habits state
  String? _folderId;
  bool _isHabit = false;
  String _habitRecurrence = 'none';
  int _habitStreak = 0;
  DateTime? _habitLastCompleted;

  // Paper Guide Layer state
  String _paperGuideType = 'lines_extra_tight';
  bool _paperGuideVisible = false;
  double _paperGuideHeight = 1.05;
  double _paperGuideOpacity = 0.15;
  int _paperGuideColor = 0;

  bool _hasChanges = false;
  bool _isPreviewMarkdown = false;
  bool _isPageSettled = false;
  int _wordCount = 0;
  int _charCount = 0;
  bool _isSaving = false;

  // Zen Focus Mode state
  Timer? _zenTimer;
  bool _isZenTyping = false;
  bool _isFormattingBarExpanded = true;
  _ActiveCategory _activeCategory = _ActiveCategory.none;

  Color get _tintColor => const Color(0xFFFFCC00);

  // Media Pickers and Record helpers
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Audio Playback state
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _colorIndex = widget.note!.colorValue;
      _isPinned = widget.note!.isPinned;
      _isFavorite = widget.note!.isFavorite;
      _isArchived = widget.note!.isArchived;
      _category = widget.note!.category;
      _noteType = widget.note!.noteType;
      _tags = List.from(widget.note!.tags);
      _attachments = List.from(widget.note!.attachments);
      _isLocked = widget.note!.isLocked;
      _reminderTime = widget.note!.reminderTime;
      _folderId = widget.note!.folderId;
      _isHabit = widget.note!.isHabit;
      _habitRecurrence = widget.note!.habitRecurrence;
      _habitStreak = widget.note!.habitStreak;
      _habitLastCompleted = widget.note!.habitLastCompleted;
      _paperGuideType = widget.note!.paperGuideType;
      _paperGuideVisible = widget.note!.paperGuideVisible;
      _paperGuideHeight = widget.note!.paperGuideHeight;
      _paperGuideOpacity = widget.note!.paperGuideOpacity;
      _paperGuideColor = widget.note!.paperGuideColor;
      
      _contentController = RichTextEditingController();
      if (NoteEditorScreen.useSingleDocumentEditor) {
        _contentController.onStyleChanged = () {
          if (mounted) setState(() {});
        };
        _contentController.onReplaceImage = _showReplaceGalleryBottomSheet;
        if (widget.note!.noteType == 'checklist') {
          // Migration: Auto-convert legacy JSON checklist to markdown checklist
          try {
            final decoded = jsonDecode(widget.note!.content) as List<dynamic>;
            final markdown = decoded.map((item) {
              final done = item['done'] == true || item['checked'] == true;
              final prefix = done ? '- [x] ' : '- [ ] ';
              return '$prefix${item['text'] ?? item['title'] ?? ''}';
            }).join('\n');
            _contentController.setMarkdown(markdown);
          } catch (_) {
            _contentController.setMarkdown(widget.note!.content);
          }
        } else {
          _contentController.setMarkdown(widget.note!.content);
        }
      } else {
        _blocks = parseMarkdownToBlocks(widget.note!.content);
      }
    } else {
      _category = widget.defaultCategory;
      _noteType = widget.defaultNoteType;
      _folderId = widget.defaultFolderId;
      _isHabit = false;
      _habitRecurrence = 'none';
      _habitStreak = 0;
      _habitLastCompleted = null;
      _paperGuideType = 'lines_extra_tight';
      _paperGuideVisible = false;
      _paperGuideHeight = 1.05;
      _paperGuideOpacity = 0.15;
      _paperGuideColor = 0;

      _contentController = RichTextEditingController();
      _contentController.onStyleChanged = () {
        if (mounted) setState(() {});
      };
      _contentController.onReplaceImage = _showReplaceGalleryBottomSheet;
      if (widget.defaultNoteType == 'checklist') {
        _contentController.setMarkdown('- [ ] ');
      }

      if (!NoteEditorScreen.useSingleDocumentEditor && _noteType == 'text') {
        final firstBlock = ParagraphBlock(id: _generateId());
        _setupBlockFocusNode(firstBlock.focusNode);
        _setupBlockController(firstBlock);
        _blocks = [firstBlock];
      }
    }
    _calculateCounts();

    _titleController.addListener(_onTitleTextChanged);
    _contentController.addListener(_onContentTextChanged);
    
    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        if (!_isFormattingBarExpanded) {
          setState(() {
            _isFormattingBarExpanded = true;
          });
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_anyBlockHasFocus && _isMetadataCollapsed) {
            setState(() {
              _isMetadataCollapsed = false;
            });
          }
        });
      }
      if (mounted) {
        setState(() {});
      }
    });
    
    _scrollController.addListener(_onScroll);
    
    _contentFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Audio player listener
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _currentlyPlayingPath = null;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);

      void _requestInitialFocus() {
        if (!mounted) return;
        setState(() { _isPageSettled = true; });
        if (widget.note == null) {
          _titleFocusNode.requestFocus();
        }
      }

      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          _requestInitialFocus();
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              route.animation!.removeStatusListener(listener);
              _requestInitialFocus();
            }
          }
          route.animation!.addStatusListener(listener);
        }
      } else {
        _requestInitialFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    _pageController.dispose();
    for (final fn in _checklistFocusNodes) {
      fn.dispose();
    }
    for (final controller in _checklistControllers) {
      controller.dispose();
    }
    for (final block in _blocks) {
      if (block is ParagraphBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      } else if (block is HeadingBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      } else if (block is QuoteBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      } else if (block is ChecklistBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      } else if (block is BulletedListBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      } else if (block is NumberedListBlock) {
        block.controller.dispose();
        block.focusNode.dispose();
      }
    }
    _recordTimer?.cancel();
    _zenTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    if (isKeyboardVisible != _isKeyboardVisible) {
      _isKeyboardVisible = isKeyboardVisible;
      setState(() {
        _isMetadataCollapsed = isKeyboardVisible;
      });
    }
  }

  void _startZenTimer() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    if (!provider.isZenModeEnabled) {
      if (_isZenTyping) {
        setState(() {
          _isZenTyping = false;
        });
      }
      return;
    }

    _zenTimer?.cancel();
    if (!_isZenTyping) {
      setState(() {
        _isZenTyping = true;
      });
    }
    _zenTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isZenTyping = false;
        });
      }
    });
  }

  void _onTitleTextChanged() {
    _calculateCounts();
    setState(() {
      _hasChanges = true;
      if (_activeCategory != _ActiveCategory.none && !Platform.environment.containsKey('FLUTTER_TEST')) {
        _activeCategory = _ActiveCategory.none;
      }
    });
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    return RichTextSelectionToolbar(editableTextState: editableTextState);
  }

  void _onContentTextChanged() {
    _calculateCounts();
    _startZenTimer();
    _checkSelectionToolbarNavigation();
    setState(() {
      _hasChanges = true;
      if (_activeCategory != _ActiveCategory.none && !Platform.environment.containsKey('FLUTTER_TEST')) {
        _activeCategory = _ActiveCategory.none;
      }
    });
  }

  void _checkSelectionToolbarNavigation() {
    if (!mounted) return;
    final selection = _contentController.selection;
    final isSelectionActive = selection.isValid && !selection.isCollapsed;

    if (isSelectionActive != _wasSelectionActive) {
      _wasSelectionActive = isSelectionActive;
      if (isSelectionActive) {
        if (_pageController.hasClients && _currentPage != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        if (_pageController.hasClients && _currentPage == 0) {
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  void _onCutSelectedText() {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _contentController.text;
    final selStart = selection.start.clamp(0, text.length);
    final selEnd = selection.end.clamp(0, text.length);
    final selectedText = text.substring(selStart, selEnd);

    Clipboard.setData(ClipboardData(text: selectedText));
    HapticFeedback.mediumImpact();

    final chars = List<StyledChar>.from(_contentController.styledChars);
    chars.removeRange(selStart, selEnd);
    _contentController.saveUndoState();
    _contentController.styledChars = chars;
    _contentController.selection = TextSelection.collapsed(offset: selStart);
  }

  void _onCopySelectedText() {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _contentController.text;
    final selStart = selection.start.clamp(0, text.length);
    final selEnd = selection.end.clamp(0, text.length);
    final selectedText = text.substring(selStart, selEnd);

    Clipboard.setData(ClipboardData(text: selectedText));
    HapticFeedback.selectionClick();
  }

  void _onSelectAllText() {
    HapticFeedback.selectionClick();
    _contentController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _contentController.text.length,
    );
  }

  void _onDeleteSelectedText() {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _contentController.text;
    final selStart = selection.start.clamp(0, text.length);
    final selEnd = selection.end.clamp(0, text.length);

    HapticFeedback.mediumImpact();

    final chars = List<StyledChar>.from(_contentController.styledChars);
    chars.removeRange(selStart, selEnd);
    _contentController.saveUndoState();
    _contentController.styledChars = chars;
    _contentController.selection = TextSelection.collapsed(offset: selStart);
  }


  NoteBlock? get _focusedBlock {
    for (final block in _blocks) {
      final fn = _getFocusNodeOfBlock(block);
      if (fn != null && fn.hasFocus) return block;
    }
    if (_lastFocusedBlock != null && _blocks.contains(_lastFocusedBlock)) {
      return _lastFocusedBlock;
    }
    for (final block in _blocks) {
      if (block is! ImageBlock && block is! DividerBlock) return block;
    }
    return null;
  }

  RichTextEditingController? get _activeController {
    if (NoteEditorScreen.useSingleDocumentEditor) return _contentController;
    final block = _focusedBlock;
    if (block is ParagraphBlock) return block.controller;
    if (block is HeadingBlock) return block.controller;
    if (block is QuoteBlock) return block.controller;
    if (block is ChecklistBlock) return block.controller;
    if (block is BulletedListBlock) return block.controller;
    if (block is NumberedListBlock) return block.controller;
    return null;
  }

  void _focusTitleArea() {
    FocusScope.of(context).requestFocus(_titleFocusNode);
    _titleController.selection = TextSelection.collapsed(offset: _titleController.text.length);
  }

  bool get _anyBlockHasFocus {
    if (_titleFocusNode.hasFocus) return true;
    if (NoteEditorScreen.useSingleDocumentEditor) {
      if (_contentFocusNode.hasFocus) return true;
    } else {
      for (final block in _blocks) {
        final fn = _getFocusNodeOfBlock(block);
        if (fn != null && fn.hasFocus) return true;
      }
    }
    return false;
  }



  void _calculateCounts() {
    String text = "";
    if (NoteEditorScreen.useSingleDocumentEditor) {
      text = _contentController.text;
    } else {
      text = _blocks.map((b) {
        if (b is ParagraphBlock) return b.controller.text;
        if (b is HeadingBlock) return b.controller.text;
        if (b is QuoteBlock) return b.controller.text;
        if (b is ChecklistBlock) return b.controller.text;
        if (b is BulletedListBlock) return b.controller.text;
        if (b is NumberedListBlock) return b.controller.text;
        return "";
      }).join(" ").trim();
    }
    setState(() {
      _charCount = text.length;
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }




  Future<void> _showGalleryBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final List<String> sampleUrls = [
      'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500&q=80',
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=500&q=80',
      'https://images.unsplash.com/photo-1472214222541-d510753a4907?w=500&q=80',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80',
    ];

    List<String> selectedPaths = [];

    if (kImageDebug) {
      debugPrint("[Stage 2] Started");
      debugPrint("Relevant state: scrollOffset=${_scrollController.hasClients ? _scrollController.offset : 'null'}");
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Insert Photo",
                          style: GoogleFonts.outfit(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedPaths.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              if (kImageDebug) {
                                debugPrint("[Stage 3 - Preset] Started");
                                debugPrint("Relevant state: image paths=$selectedPaths");
                              }
                              Navigator.pop(context);
                              _insertSelectedImages(selectedPaths);
                              if (kImageDebug) {
                                debugPrint("[Stage 3 - Preset] Completed");
                              }
                            },
                            child: Text(
                              "Insert (${selectedPaths.length})",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: sampleUrls.length + 2,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return InkWell(
                              onTap: () async {
                                  if (kImageDebug) {
                                    debugPrint("[Stage 3 - Camera] Started");
                                  }
                                  Navigator.pop(context);
                                  final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                                  if (picked != null) {
                                    if (kImageDebug) {
                                      debugPrint("Relevant state: image path=file://${picked.path}");
                                    }
                                    _insertSelectedImages(['file://${picked.path}']);
                                  }
                                  if (kImageDebug) {
                                    debugPrint("[Stage 3 - Camera] Completed");
                                  }
                                },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 28),
                                    SizedBox(height: 4),
                                    Text("Camera", style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          } else if (index == 1) {
                            return InkWell(
                              onTap: () async {
                                  if (kImageDebug) {
                                    debugPrint("[Stage 3 - Gallery] Started");
                                  }
                                  Navigator.pop(context);
                                  final pickedList = await _imagePicker.pickMultiImage();
                                  if (pickedList.isNotEmpty) {
                                    final paths = pickedList.map((x) => 'file://${x.path}').toList();
                                    if (kImageDebug) {
                                      debugPrint("Relevant state: image paths=$paths");
                                    }
                                    _insertSelectedImages(paths);
                                  }
                                  if (kImageDebug) {
                                    debugPrint("[Stage 3 - Gallery] Completed");
                                  }
                                },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 28),
                                    SizedBox(height: 4),
                                    Text("System Gallery", style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final url = sampleUrls[index - 2];
                            final isSelected = selectedPaths.contains(url);
                            final selectIdx = selectedPaths.indexOf(url) + 1;

                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedPaths.remove(url);
                                  } else {
                                    selectedPaths.add(url);
                                  }
                                });
                              },
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: theme.colorScheme.primary, width: 3),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: theme.colorScheme.primary,
                                        child: Text(
                                          "$selectIdx",
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _insertSelectedImages(List<String> paths) async {
    if (kImageDebug) {
      debugPrint("[Stage 4] Started");
      debugPrint("Relevant state: paths=$paths, selection=${_contentController.selection}, styledChars length=${_contentController.styledChars.length}");
    }
    if (_noteType == 'text' && NoteEditorScreen.useSingleDocumentEditor) {
      for (final path in paths) {
        _contentController.insertImage(path);
      }
      setState(() {
        _hasChanges = true;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _contentFocusNode.requestFocus();
          final sdeState = _sdeKey.currentState;
          if (sdeState != null) {
            sdeState.scrollToActiveSegment();
          } else {
            _scrollToCursor();
          }
        }
      });
      if (kImageDebug) {
        debugPrint("[Stage 4] Completed");
      }
      return;
    }

    for (final path in paths) {
      if (_noteType == 'text') {
        final activeBlock = _focusedBlock;
        if (activeBlock != null) {
          final index = _blocks.indexOf(activeBlock);
          if (index != -1) {
            String textBefore = "";
            String textAfter = "";
            List<StyledChar> charsBefore = [];
            List<StyledChar> charsAfter = [];

            final activeController = _getControllerOfBlock(activeBlock);
            if (activeController != null) {
              final sel = activeController.selection;
              final text = activeController.text;
              final styledChars = activeController.styledChars;

              int cursor = sel.isValid ? sel.start : text.length;
              cursor = cursor.clamp(0, text.length);

              textBefore = text.substring(0, cursor);
              textAfter = text.substring(cursor);
              charsBefore = styledChars.take(cursor).toList();
              charsAfter = styledChars.skip(cursor).toList();
            }

            final beforeBlock = ParagraphBlock(id: _generateId());
            _setupBlockFocusNode(beforeBlock.focusNode);
            _setupBlockController(beforeBlock);
            beforeBlock.controller.styledChars = charsBefore;
            beforeBlock.controller.text = textBefore;

            final imgBlock = ImageBlock(id: _generateId(), imageUrl: path);

            final afterBlock = ParagraphBlock(id: _generateId());
            _setupBlockFocusNode(afterBlock.focusNode);
            _setupBlockController(afterBlock);
            afterBlock.controller.styledChars = charsAfter;
            afterBlock.controller.text = textAfter;

            setState(() {
              _blocks.removeAt(index);
              _blocks.insert(index, beforeBlock);
              _blocks.insert(index + 1, imgBlock);
              _blocks.insert(index + 2, afterBlock);
              _hasChanges = true;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              afterBlock.focusNode.requestFocus();
              afterBlock.controller.selection = const TextSelection.collapsed(offset: 0);
            });
          }
        } else {
          final imgBlock = ImageBlock(id: _generateId(), imageUrl: path);
          final afterBlock = ParagraphBlock(id: _generateId());
          _setupBlockFocusNode(afterBlock.focusNode);
          _setupBlockController(afterBlock);
          setState(() {
            _blocks.add(imgBlock);
            _blocks.add(afterBlock);
            _hasChanges = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            afterBlock.focusNode.requestFocus();
          });
        }
      } else {
        setState(() {
          _attachments.add({
            'type': 'image',
            'path': path.startsWith('file://') ? path.substring(7) : path,
          });
          _hasChanges = true;
        });
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> _showReplaceGalleryBottomSheet(int index, {int? stackImageIndex}) async {
    final theme = Theme.of(context);
    final List<String> sampleUrls = [
      'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500&q=80',
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=500&q=80',
      'https://images.unsplash.com/photo-1472214222541-d510753a4907?w=500&q=80',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80',
    ];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replace Photo",
                  style: GoogleFonts.outfit(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: sampleUrls.length + 2,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, gridIndex) {
                      if (gridIndex == 0) {
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                            if (picked != null) {
                              _replaceImage(index, 'file://${picked.path}', stackImageIndex: stackImageIndex);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 28),
                                SizedBox(height: 4),
                                Text("Camera", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      } else if (gridIndex == 1) {
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              _replaceImage(index, 'file://${picked.path}', stackImageIndex: stackImageIndex);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 28),
                                SizedBox(height: 4),
                                Text("System Gallery", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      } else {
                        final url = sampleUrls[gridIndex - 2];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _replaceImage(index, url, stackImageIndex: stackImageIndex);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replaceImage(int index, String newPath, {int? stackImageIndex}) {
    if (_noteType == 'text' && NoteEditorScreen.useSingleDocumentEditor) {
      if (index >= 0 && index < _contentController.styledChars.length) {
        final sc = _contentController.styledChars[index];
        if (sc.char == '\uFFFC' && sc.style.imageUrl != null) {
          setState(() {
            _contentController.styledChars[index] = StyledChar(
              char: sc.char,
              style: sc.style.copyWith(imageUrl: newPath),
            );
            _contentController.notifyListeners();
            _hasChanges = true;
          });
        }
      }
      return;
    }

    if (index >= 0 && index < _blocks.length) {
      final block = _blocks[index];
      if (stackImageIndex != null && block is ImageStackBlock) {
        setState(() {
          final oldImg = block.images[stackImageIndex];
          block.images[stackImageIndex] = ImageBlock(
            id: oldImg.id,
            imageUrl: newPath,
            width: oldImg.width,
            caption: oldImg.caption,
          );
          _hasChanges = true;
        });
      } else if (block is ImageBlock) {
        setState(() {
          _blocks[index] = ImageBlock(
            id: block.id,
            imageUrl: newPath,
            width: block.width,
            caption: block.caption,
          );
          _hasChanges = true;
        });
      }
    }
  }



  // --- Audio Recording operations ---
  Future<void> _startRecording() async {
    try {
      final isGranted = await Permission.microphone.request().isGranted;
      if (!mounted) return;

      if (isGranted) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission denied")),
        );
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _attachments.add({
            'type': 'voice',
            'path': path,
            'duration': _recordDuration,
          });
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  Future<void> _toggleAudioPlay(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _currentlyPlayingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  /// Restores keyboard focus to the SDE content field after a toolbar action.
  /// Uses a post-frame callback so it runs after the build cycle triggered
  /// by `toggleParagraphStyle` / `insertDivider` has completed.
  void _restoreContentFocus() {
    if (!NoteEditorScreen.useSingleDocumentEditor) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });
    setState(() { _hasChanges = true; });
  }

  void _scrollToCursor() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  double _getDynamicBottomScrollPadding() {
    final double currentToolbarHeight = !_isFormattingBarExpanded 
        ? 48.0 
        : (_activeCategory != _ActiveCategory.none ? 100.0 : 50.0);
    return MediaQuery.of(context).viewInsets.bottom + currentToolbarHeight + 30.0;
  }

  // --- Save Operations ---
  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final title = _titleController.text.trim();
      final content = NoteEditorScreen.useSingleDocumentEditor
          ? generateMarkdownFromStyledChars(_contentController.styledChars).trim()
          : _blocks.map((b) => b.toMarkdown()).join('\n').trim();

      if (title.isEmpty && content.isEmpty) return;

      final provider = Provider.of<NotesProvider>(context, listen: false);

      if (widget.note == null) {
        await provider.addNote(
          title: title,
          content: content,
          colorIndex: _colorIndex,
          category: _category,
          noteType: _noteType,
          tags: _tags,
          attachments: _attachments,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          isLocked: _isLocked,
          reminderTime: _reminderTime,
          folderId: _folderId,
          isHabit: _isHabit,
          habitRecurrence: _habitRecurrence,
          paperGuideType: _paperGuideType,
          paperGuideVisible: _paperGuideVisible,
          paperGuideHeight: _paperGuideHeight,
          paperGuideOpacity: _paperGuideOpacity,
          paperGuideColor: _paperGuideColor,
        );
      } else {
        final updatedNote = widget.note!.copyWith(
          title: title,
          content: content,
          colorValue: _colorIndex,
          category: _category,
          noteType: _noteType,
          tags: _tags,
          attachments: _attachments,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          isLocked: _isLocked,
          reminderTime: _reminderTime,
          folderId: _folderId,
          isHabit: _isHabit,
          habitRecurrence: _habitRecurrence,
          habitStreak: _habitStreak,
          habitLastCompleted: _habitLastCompleted,
          paperGuideType: _paperGuideType,
          paperGuideVisible: _paperGuideVisible,
          paperGuideHeight: _paperGuideHeight,
          paperGuideOpacity: _paperGuideOpacity,
          paperGuideColor: _paperGuideColor,
        );
        await provider.updateNote(updatedNote);
      }
      
      setState(() {
        _hasChanges = false;
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_isRecording) {
      await _stopRecording();
    }
    await _audioPlayer.stop();

    if (_hasChanges && !_isSaving) {
      await _saveNote();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note auto-saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
    return true;
  }

  void _addTag() {
    final value = _tagController.text.trim().toLowerCase();
    if (value.isNotEmpty && !_tags.contains(value)) {
      setState(() {
        _tags.add(value);
        _tagController.clear();
        _hasChanges = true;
      });
    }
  }

  void _toggleBlockType(NoteBlock block, Type targetType, {int? headingLevel, bool? isChecked}) {
    final index = _blocks.indexOf(block);
    if (index == -1) return;

    String text = "";
    List<StyledChar> styledChars = [];
    TextSelection selection = const TextSelection.collapsed(offset: 0);

    if (block is ParagraphBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    } else if (block is HeadingBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    } else if (block is QuoteBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    } else if (block is ChecklistBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    } else if (block is BulletedListBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    } else if (block is NumberedListBlock) {
      text = block.controller.text;
      styledChars = block.controller.styledChars;
      selection = block.controller.selection;
      block.focusNode.unfocus();
    }

    NoteBlock newBlock;
    final id = block.id;

    if (targetType == HeadingBlock) {
      newBlock = HeadingBlock(id: id, level: headingLevel ?? 1, markdown: "");
    } else if (targetType == QuoteBlock) {
      newBlock = QuoteBlock(id: id, markdown: "");
    } else if (targetType == ChecklistBlock) {
      newBlock = ChecklistBlock(id: id, isChecked: isChecked ?? false, markdown: "");
    } else if (targetType == BulletedListBlock) {
      newBlock = BulletedListBlock(id: id, markdown: "");
    } else if (targetType == NumberedListBlock) {
      newBlock = NumberedListBlock(id: id, markdown: "");
    } else if (targetType == DividerBlock) {
      newBlock = DividerBlock(id: id);
    } else {
      newBlock = ParagraphBlock(id: id, markdown: "");
    }

    if (newBlock is ParagraphBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is HeadingBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is QuoteBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is ChecklistBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is BulletedListBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is NumberedListBlock) {
      newBlock.controller.text = text;
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    }

    setState(() {
      _blocks[index] = newBlock;
      _hasChanges = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fn = _getFocusNodeOfBlock(newBlock);
      if (fn != null) {
        fn.requestFocus();
      }
    });
  }

  void _wrapSelection(String prefix, String suffix) {
    if (_noteType == 'text') {
      final controller = _activeController;
      if (controller == null) return;

      if (prefix == '**') {
        controller.toggleStyleAttribute('bold');
      } else if (prefix == '*') {
        controller.toggleStyleAttribute('italic');
      } else if (prefix == '<u>') {
        controller.toggleStyleAttribute('underline');
      } else if (prefix == '~~') {
        controller.toggleStyleAttribute('strikethrough');
      } else if (prefix == 'highlight') {
        controller.toggleStyleAttribute('highlight', value: Colors.yellow.withAlpha(180));
      } else if (prefix == '```\n') {
        controller.toggleStyleAttribute('code');
      } else if (prefix.startsWith('<p align="')) {
        final alignName = prefix.split('"')[1];
        controller.toggleParagraphStyle('align-$alignName');
      } else {
        final text = controller.text;
        final selection = controller.selection;
        int start = selection.start;
        int end = selection.end;
        if (start == -1 || end == -1) {
          start = text.length;
          end = start;
        }
        final selectedText = text.substring(start, end);
        final replacement = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(start, end, replacement);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: start + prefix.length,
            extentOffset: start + prefix.length + selectedText.length,
          ),
        );
      }
      _calculateCounts();
      _startZenTimer();
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start;
    int end = selection.end;
    if (start == -1 || end == -1) {
      start = text.length;
      end = start;
    }
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      ),
    );
    _onContentTextChanged();
  }

  void _insertTextAtCursor(String textToInsert) {
    if (_noteType == 'text') {
      final controller = _activeController;
      if (controller == null) return;

      if (NoteEditorScreen.useSingleDocumentEditor) {
        if (textToInsert == '> ') {
          controller.toggleParagraphStyle('quote');
        } else if (textToInsert == '# ') {
          controller.toggleParagraphStyle('h1');
        } else if (textToInsert == '## ') {
          controller.toggleParagraphStyle('h2');
        } else if (textToInsert == '### ') {
          controller.toggleParagraphStyle('h3');
        } else if (textToInsert == '- ') {
          controller.toggleParagraphStyle('bullet');
        } else if (textToInsert == '1. ') {
          controller.toggleParagraphStyle('number');
        } else if (textToInsert == '\u2610') {
          controller.toggleParagraphStyle('checkbox');
        } else {
          final text = controller.text;
          final selection = controller.selection;
          int start = selection.start;
          int end = selection.end;
          if (start == -1 || end == -1) {
            start = text.length;
            end = start;
          }
          final newText = text.replaceRange(start, end, textToInsert);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start + textToInsert.length),
          );
        }
      } else {
        if (textToInsert == '> ') {
          final block = _focusedBlock;
          if (block != null) _toggleBlockType(block, QuoteBlock);
        } else if (textToInsert == '# ') {
          final block = _focusedBlock;
          if (block != null) _toggleBlockType(block, HeadingBlock, headingLevel: 1);
        } else if (textToInsert == '## ') {
          final block = _focusedBlock;
          if (block != null) _toggleBlockType(block, HeadingBlock, headingLevel: 2);
        } else if (textToInsert == '### ') {
          final block = _focusedBlock;
          if (block != null) _toggleBlockType(block, HeadingBlock, headingLevel: 3);
        } else if (textToInsert == '- ') {
          controller.toggleParagraphStyle('bullet');
        } else if (textToInsert == '1. ') {
          controller.toggleParagraphStyle('number');
        } else if (textToInsert == '\u2610') {
          final block = _focusedBlock;
          if (block != null) _toggleBlockType(block, ChecklistBlock);
        } else {
          final text = controller.text;
          final selection = controller.selection;
          int start = selection.start;
          int end = selection.end;
          if (start == -1 || end == -1) {
            start = text.length;
            end = start;
          }
          final newText = text.replaceRange(start, end, textToInsert);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start + textToInsert.length),
          );
        }
      }
      _calculateCounts();
      _startZenTimer();
      setState(() {
        _hasChanges = true;
      });
      return;
    }

    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start;
    int end = selection.end;
    if (start == -1 || end == -1) {
      start = text.length;
      end = start;
    }
    final newText = text.replaceRange(start, end, textToInsert);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );
    _onContentTextChanged();
  }

  Future<void> _pickReminder() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _hasChanges = true;
        });
      }
    }
  }

  void _onDeleteNoteSelected() async {
    setState(() => _isNoteOptionsOpen = false);
    if (widget.note == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final confirm = await showDeleteNoteDialog(context);

    if (confirm == true && mounted) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      await provider.deleteNote(widget.note!.id);
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  // Command bar floating modal bottom sheet actions hub
  void _showCommandPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCommandItem(
                context,
                icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: _isPinned ? "Unpin Note" : "Pin Note",
                onTap: () {
                  setState(() {
                    _isPinned = !_isPinned;
                    _hasChanges = true;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: _isPreviewMarkdown ? Icons.edit_note : Icons.chrome_reader_mode,
                label: _isPreviewMarkdown ? "Edit Note" : "Preview Markdown",
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isPreviewMarkdown = !_isPreviewMarkdown;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: _isFavorite ? Icons.star : Icons.star_border,
                label: _isFavorite ? "Remove Favorite" : "Add Favorite",
                onTap: () {
                  setState(() {
                    _isFavorite = !_isFavorite;
                    _hasChanges = true;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: Icons.folder_open_outlined,
                label: "Move to Folder",
                onTap: _showFolderSelectorDialog,
              ),
              _buildCommandItem(
                context,
                icon: _isLocked ? Icons.lock : Icons.lock_open,
                label: _isLocked ? "Unlock Note" : "Lock Note with PIN",
                onTap: () async {
                  if (!_isLocked) {
                    final hasPin = await VaultService.instance.hasPinConfigured();
                    if (!hasPin && mounted) {
                      _showSetupPinDialog();
                      return;
                    }
                  }
                  setState(() {
                    _isLocked = !_isLocked;
                    _hasChanges = true;
                  });
                },
              ),

              _buildCommandItem(
                context,
                icon: Icons.grid_on_rounded,
                label: "Configure Paper & Spacing",
                onTap: _showPaperSettingsBottomSheet,
              ),
              _buildCommandItem(
                context,
                icon: Icons.share_rounded,
                label: "Export & Share",
                onTap: _showExportDialog,
              ),
              _buildCommandItem(
                context,
                icon: Icons.add_circle_outline_rounded,
                label: "Attachments & Tags...",
                onTap: () {
                  Navigator.pop(context); // close command palette
                  _showQuickAddMenu();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showPaperSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            final List<Map<String, dynamic>> guideOptions = [
              {'type': 'plain', 'label': 'Plain', 'icon': Icons.crop_free_rounded},
              {'type': 'grid', 'label': 'Grid', 'icon': Icons.grid_on_rounded},
              {'type': 'dots', 'label': 'Dots', 'icon': Icons.blur_on_rounded},
              {'type': 'lines_extra_tight', 'label': 'Lines (Extra Tight)', 'icon': Icons.format_align_justify_rounded},
              {'type': 'lines_tight', 'label': 'Lines (Tight)', 'icon': Icons.notes_rounded},
              {'type': 'lines_comfort', 'label': 'Lines (Comfort)', 'icon': Icons.menu_rounded},
              {'type': 'custom', 'label': 'Custom Lines', 'icon': Icons.tune_rounded},
            ];

            final List<int> presetColors = [
              0, // Default (Theme aware)
              0xFF4EA8DE, // Subtle Blue
              0xFFF07167, // Subtle Red
              0xFF40916C, // Subtle Green
              0xFFF77F00, // Subtle Amber
            ];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Paper & Spacing Setup",
                        style: GoogleFonts.outfit(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggle Switch for Visibility
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Show Writing Guides",
                        style: GoogleFonts.inter(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Switch(
                        value: _paperGuideVisible,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (val) {
                          setSheetState(() {
                            _paperGuideVisible = val;
                          });
                          setState(() {
                            _paperGuideVisible = val;
                            _hasChanges = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (_paperGuideVisible) ...[
                    Text(
                      "Guide Style",
                      style: GoogleFonts.outfit(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Style list
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: guideOptions.length,
                        itemBuilder: (context, idx) {
                          final opt = guideOptions[idx];
                          final optType = opt['type'] as String;
                          final isSelected = _paperGuideType == optType;

                          return GestureDetector(
                            onTap: () {
                              double newHeight = _paperGuideHeight;
                              if (optType == 'lines_extra_tight') {
                                newHeight = 1.05;
                              } else if (optType == 'lines_tight') {
                                newHeight = 1.3;
                              } else if (optType == 'lines_comfort') {
                                newHeight = 1.6;
                              } else if (optType == 'custom') {
                                newHeight = 1.3; // Default custom height factor
                              }

                              setSheetState(() {
                                _paperGuideType = optType;
                                _paperGuideHeight = newHeight;
                              });
                              setState(() {
                                _paperGuideType = optType;
                                _paperGuideHeight = newHeight;
                                _hasChanges = true;
                              });
                            },
                            child: Container(
                              width: 85,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? theme.colorScheme.primary.withOpacity(0.15) 
                                    : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F3EF)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? theme.colorScheme.primary 
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    opt['icon'] as IconData,
                                    color: isSelected 
                                        ? theme.colorScheme.primary 
                                        : (isDark ? Colors.white70 : Colors.black54),
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    opt['label'] as String,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected 
                                          ? theme.colorScheme.primary 
                                          : (isDark ? Colors.white60 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Custom Height Slider (visible only in custom mode)
                    if (_paperGuideType == 'custom') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Line Height Factor: ${_paperGuideHeight.toStringAsFixed(2)}",
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "${(_paperGuideHeight * 20).toInt()} px",
                            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      Slider(
                        value: _paperGuideHeight,
                        min: 1.0,
                        max: 2.5,
                        divisions: 30,
                        onChanged: (val) {
                          setSheetState(() {
                            _paperGuideHeight = val;
                          });
                          setState(() {
                            _paperGuideHeight = val;
                            _hasChanges = true;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Opacity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Guide Opacity: ${(_paperGuideOpacity * 100).toInt()}%",
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Slider(
                      value: _paperGuideOpacity,
                      min: 0.05,
                      max: 0.60,
                      divisions: 11,
                      onChanged: (val) {
                        setSheetState(() {
                          _paperGuideOpacity = val;
                        });
                        setState(() {
                          _paperGuideOpacity = val;
                          _hasChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Color Selector
                    if (_paperGuideType != 'plain') ...[
                      Text(
                        "Guide Color",
                        style: GoogleFonts.outfit(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: presetColors.length,
                          itemBuilder: (context, index) {
                            final colVal = presetColors[index];
                            final isSelected = _paperGuideColor == colVal;

                            Color displayCol;
                            if (colVal == 0) {
                              displayCol = isDark ? Colors.white60 : Colors.black45;
                            } else {
                              displayCol = Color(colVal);
                            }

                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  _paperGuideColor = colVal;
                                });
                                setState(() {
                                  _paperGuideColor = colVal;
                                  _hasChanges = true;
                                });
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: displayCol.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? theme.colorScheme.primary : displayCol,
                                    width: isSelected ? 3.0 : 1.5,
                                  ),
                                ),
                                child: colVal == 0
                                    ? Center(
                                        child: Icon(
                                          Icons.autorenew_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategorySelector(Color titleColor) {
    const categories = NotesProvider.categories;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _category == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : titleColor.withAlpha(180),
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: titleColor.withAlpha(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : titleColor.withAlpha(30),
                  width: 1.0,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _category = cat;
                    _hasChanges = true;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormattingToolbar(Color textColor, Color titleColor) {
    final theme = Theme.of(context);
    final buttonColor = titleColor;
    final isDark = theme.brightness == Brightness.dark;

    final activeStyle = (_contentController is RichTextEditingController)
        ? (_contentController as RichTextEditingController).currentActiveStyle
        : const Style();

    // Helper for building toolbar items
    Widget buildToolbarButton({
      required IconData icon,
      required VoidCallback onPressed,
      required String tooltip,
      bool isActive = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Tooltip(
          message: tooltip,
          child: TactileButton(
            useAppleSpring: true,
            compressionScale: 0.8,
            settleDuration: const Duration(milliseconds: 1000),
            onTap: onPressed,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary.withAlpha(40) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isActive ? theme.colorScheme.primary : buttonColor.withAlpha(200),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildPageWrapper(List<Widget> children) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    }

    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: buttonColor.withAlpha(25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left chevron arrow to navigate back
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 0,
              child: IconButton(
                icon: Transform(
                  transform: Matrix4.rotationY(3.14159),
                  alignment: Alignment.center,
                  child: Icon(Icons.play_arrow_rounded, color: buttonColor.withAlpha(180)),
                ),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
          
          // Sliding Options
          Expanded(
            child: SizedBox(
              height: 44,
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 0: Selection Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.content_cut_rounded,
                      onPressed: _onCutSelectedText,
                      tooltip: 'Cut',
                    ),
                    buildToolbarButton(
                      icon: Icons.copy_rounded,
                      onPressed: _onCopySelectedText,
                      tooltip: 'Copy',
                    ),
                    buildToolbarButton(
                      icon: Icons.select_all_rounded,
                      onPressed: _onSelectAllText,
                      tooltip: 'Select All',
                    ),
                    buildToolbarButton(
                      icon: Icons.delete_outline_rounded,
                      onPressed: _onDeleteSelectedText,
                      tooltip: 'Delete',
                    ),
                  ]),

                  // Page 1: Styles Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.format_bold_rounded,
                      onPressed: () => _wrapSelection('**', '**'),
                      tooltip: 'Bold',
                      isActive: activeStyle.bold,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_italic_rounded,
                      onPressed: () => _wrapSelection('*', '*'),
                      tooltip: 'Italic',
                      isActive: activeStyle.italic,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_underlined_rounded,
                      onPressed: () => _wrapSelection('<u>', '</u>'),
                      tooltip: 'Underline',
                      isActive: activeStyle.underline,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_strikethrough_rounded,
                      onPressed: () => _wrapSelection('~~', '~~'),
                      tooltip: 'Strikethrough',
                      isActive: activeStyle.strikethrough,
                    ),
                    buildToolbarButton(
                      icon: Icons.border_color_rounded,
                      onPressed: () => _wrapSelection('highlight', ''),
                      tooltip: 'Highlight',
                      isActive: activeStyle.highlight != null,
                    ),
                    buildToolbarButton(
                      icon: Icons.link_rounded,
                      onPressed: () => _wrapSelection('[', '](url)'),
                      tooltip: 'Link',
                    ),
                  ]),

                  // Page 2: Headings & Lists Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.filter_1_rounded,
                      onPressed: () => _insertTextAtCursor('# '),
                      tooltip: 'Heading 1',
                      isActive: activeStyle.heading == 'h1',
                    ),
                    buildToolbarButton(
                      icon: Icons.filter_2_rounded,
                      onPressed: () => _insertTextAtCursor('## '),
                      tooltip: 'Heading 2',
                      isActive: activeStyle.heading == 'h2',
                    ),
                    buildToolbarButton(
                      icon: Icons.filter_3_rounded,
                      onPressed: () => _insertTextAtCursor('### '),
                      tooltip: 'Heading 3',
                      isActive: activeStyle.heading == 'h3',
                    ),
                    buildToolbarButton(
                      icon: Icons.format_list_bulleted_rounded,
                      onPressed: () => _insertTextAtCursor('- '),
                      tooltip: 'Bullet List',
                      isActive: activeStyle.listType == 'bullet',
                    ),
                    buildToolbarButton(
                      icon: Icons.format_list_numbered_rounded,
                      onPressed: () => _insertTextAtCursor('1. '),
                      tooltip: 'Numbered List',
                      isActive: activeStyle.listType == 'number',
                    ),
                    buildToolbarButton(
                      icon: Icons.add_task_rounded,
                      onPressed: () => _insertTextAtCursor('\u2610'),
                      tooltip: 'Checklist',
                      isActive: activeStyle.listType == 'checkbox',
                    ),
                    buildToolbarButton(
                      icon: Icons.grid_on_rounded,
                      onPressed: _showPaperSettingsBottomSheet,
                      tooltip: 'Paper Settings',
                    ),
                  ]),

                  // Page 3: Alignments & Actions Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.format_align_left_rounded,
                      onPressed: () => _wrapSelection('<p align="left">', '</p>'),
                      tooltip: 'Align Left',
                      isActive: activeStyle.align == TextAlign.left,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_center_rounded,
                      onPressed: () => _wrapSelection('<p align="center">', '</p>'),
                      tooltip: 'Align Center',
                      isActive: activeStyle.align == TextAlign.center,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_right_rounded,
                      onPressed: () => _wrapSelection('<p align="right">', '</p>'),
                      tooltip: 'Align Right',
                      isActive: activeStyle.align == TextAlign.right,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_justify_rounded,
                      onPressed: () => _wrapSelection('<p align="justify">', '</p>'),
                      tooltip: 'Align Justify',
                      isActive: activeStyle.align == TextAlign.justify,
                    ),
                    buildToolbarButton(
                      icon: Icons.camera_alt_outlined,
                      onPressed: () => _showGalleryBottomSheet(context),
                      tooltip: 'Attach Image',
                    ),
                    buildToolbarButton(
                      icon: Icons.mic_none_rounded,
                      onPressed: _startRecording,
                      tooltip: 'Record Audio',
                    ),
                    buildToolbarButton(
                      icon: Icons.keyboard_hide_rounded,
                      onPressed: () => FocusScope.of(context).unfocus(),
                      tooltip: 'Hide Keyboard',
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // Right chevron arrow to navigate forward
          AnimatedOpacity(
            opacity: _currentPage < 3 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 3,
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: buttonColor.withAlpha(180)),
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardBottomPanel(Color editorBgColor, Color titleColor, Color textColor, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$_wordCount words  |  $_charCount chars",
              style: GoogleFonts.inter(fontSize: 11.0, color: textColor.withAlpha(150)),
            ),
            SizedBox(
              height: 24,
              child: Row(
                children: List.generate(8, (index) {
                  final color = NotesProvider.getNoteColor(index, context);
                  final isSelected = _colorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _colorIndex = index;
                        _hasChanges = true;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.black12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFEBEBE8)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _showCommandPalette,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.more_horiz_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Note Actions",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: 1,
                  height: 18,
                  child: ColoredBox(color: Color(0xFFEBEBE8)),
                ),
                InkWell(
                  onTap: _showQuickAddMenu,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          "Attachments",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /*
  bool get _isNoteEmpty {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    if (hasTitle) return false;
    
    if (_noteType == 'checklist') {
      return _checklistItems.isEmpty;
    }
    
    if (_blocks.length > 1) return false;
    if (_blocks.isEmpty) return true;
    
    final firstBlock = _blocks[0];
    if (firstBlock is ParagraphBlock) {
      return firstBlock.controller.text.isEmpty && _attachments.isEmpty && _tags.isEmpty;
    }
    
    return false;
  }
  */

  void _showCategorySelectorDialog() {
    showBlurredBottomSheet(
      context: context,
      child: CategorySelectionSheet(
        currentCategory: _category,
        onCategorySelected: (cat) {
          setState(() {
            _category = cat;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  /*
  Widget _buildStartingScreen(ThemeData theme, bool isDark) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EE),
      body: SafeArea(
        child: Stack(
          children: [
            HomePromptView(
              date: widget.note?.createdAt ?? DateTime.now(),
              interactive: true,
              controller: _getControllerOfBlock(_blocks[0]),
              focusNode: _getFocusNodeOfBlock(_blocks[0]),
              onChanged: (val) {
                _onBlockTextChanged(_blocks[0]);
                setState(() {}); // Rebuild to transition to active screen
              },
            ),
            
            // Bottom navigation bar
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Center(
                child: SizedBox(
                  width: 354,
                  height: 83,
                  child: Stack(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/bottom_bar.svg',
                        width: 354,
                        height: 83,
                      ),
                      Positioned(
                        left: 31,
                        top: 39,
                        width: 26,
                        height: 26,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      Positioned(
                        left: 106,
                        top: 39,
                        width: 26,
                        height: 26,
                        child: GestureDetector(
                          onTap: _showFolderSelectorDialog,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      Positioned(
                        left: 152,
                        top: 0,
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            final fn = _getFocusNodeOfBlock(_blocks[0]);
                            if (fn != null) fn.requestFocus();
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      Positioned(
                        left: 222,
                        top: 40,
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: _showQuickAddMenu,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      Positioned(
                        left: 297,
                        top: 39,
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: _showCommandPalette,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  */

Widget _buildActiveEditorScreen(ThemeData theme, bool isDark) {
    final notesProvider = Provider.of<NotesProvider>(context);
    
    final RichTextEditingController? currentController = (_noteType == 'text')
        ? _activeController
        : (_contentController is RichTextEditingController ? _contentController as RichTextEditingController : null);
    final activeStyle = currentController != null
        ? currentController.currentActiveStyle
        : const Style();
    
    final noteDate = widget.note?.createdAt ?? DateTime.now();
    final dateStr = DateFormat('EEE, d MMMM yyyy').format(noteDate);
    final timeStr = DateFormat('hh:mm a').format(noteDate);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final double targetWidth = _isFormattingBarExpanded ? (screenWidth - 48.0) : 48.0;
    final double targetHeight = !_isFormattingBarExpanded ? 48.0 : (_activeCategory != _ActiveCategory.none ? 100.0 : 50.0);
    final double targetLeft = _isFormattingBarExpanded 
        ? 24.0 
        : (screenWidth - targetWidth - 24.0);

    const textColor = Color(0xFF1C1C1E);
    const titleColor = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Note Card Hero Container
            Positioned(
              left: 0.0,
              right: 0.0,
              top: 74.0, // starts below the top bar buttons
              bottom: 0.0,
              child: Stack(
                children: [
                  // 1. Background Card (Hero-wrapped)
                  Positioned.fill(
                    child: Hero(
                      tag: 'hero_note_card_${widget.note?.id ?? 'new'}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 20.0,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 100.0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFCC00),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(30.0),
                                      topRight: Radius.circular(30.0),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 50.0,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(30.0),
                                      topRight: Radius.circular(30.0),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 1.5 Global Paper Guide Painter (if visible, drawn inside the rounded card over the white background)
                  if (_paperGuideVisible && 
                      ((_paperGuideType == 'grid' || _paperGuideType == 'dots') || 
                       (NoteEditorScreen.useSingleDocumentEditor && (_paperGuideType.startsWith('lines') || _paperGuideType == 'custom'))))
                    Positioned(
                      top: 50.0, // starts below the card curve
                      left: 0.0,
                      right: 0.0,
                      bottom: 0.0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30.0),
                          topRight: Radius.circular(30.0),
                        ),
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: ValueKey('${_paperGuideType}_${_paperGuideColor}_${_paperGuideOpacity}'),
                            painter: GlobalPaperGuidePainter(
                              guideType: _paperGuideType,
                              spacing: (NoteEditorScreen.useSingleDocumentEditor && (_paperGuideType.startsWith('lines') || _paperGuideType == 'custom'))
                                  ? (16.0 * 1.35 * _paperGuideHeight)
                                  : (20.0 * _paperGuideHeight),
                              color: _getPaperGuideColor(isDark),
                              opacity: _paperGuideOpacity,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Scrollable Writing Content Area & Sticky Translucent Blur Header
                  Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              _pointerDownPos = event.position;
                              _activeDragImage = null;
                              _dragDirection = 0;
                              
                              final controller = _contentController;
                              for (final entry in controller.imageKeys.entries) {
                                final key = entry.value;
                                final context = key.currentContext;
                                if (context != null) {
                                  final RenderBox? box = context.findRenderObject() as RenderBox?;
                                  if (box != null && box.hasSize) {
                                    final position = box.localToGlobal(Offset.zero);
                                    final size = box.size;
                                    final rect = position & size;
                                    if (rect.contains(event.position)) {
                                      _activeDragImage = key.currentState as ResizableImageWidgetState?;
                                      if (_activeDragImage != null) {
                                        final isControlsShown = _activeDragImage!.showControls;
                                        final localX = event.position.dx - position.dx;
                                        if (isControlsShown && localX < 30.0) {
                                          _dragDirection = -1; // Left handle
                                        } else if (isControlsShown && localX > size.width - 30.0) {
                                          _dragDirection = 1; // Right handle
                                        } else {
                                          _dragDirection = 0; // Tap/double-tap area
                                        }
                                      }
                                      break;
                                    }
                                  }
                                }
                              }
                            },
                            onPointerMove: (event) {
                              if (_activeDragImage != null && _dragDirection != 0) {
                                _activeDragImage!.updateWidth(event.delta.dx, _dragDirection);
                              }
                            },
                            onPointerUp: (event) {
                              if (_activeDragImage != null) {
                                final dist = _pointerDownPos != null ? (event.position - _pointerDownPos!).distance : 0.0;
                                if (dist < 10.0 && _dragDirection == 0) {
                                  _activeDragImage!.toggleControls();
                                }
                                _activeDragImage = null;
                                _dragDirection = 0;
                              } else {
                                final dist = _pointerDownPos != null ? (event.position - _pointerDownPos!).distance : 0.0;
                                if (dist < 10.0) {
                                  if (NoteEditorScreen.useSingleDocumentEditor) {
                                    bool isInsideSDE = false;
                                    final BuildContext? sdeContext = _sdeKey.currentContext;
                                    if (sdeContext != null) {
                                      final RenderBox? box = sdeContext.findRenderObject() as RenderBox?;
                                      if (box != null && box.hasSize) {
                                        final position = box.localToGlobal(Offset.zero);
                                        final rect = position & box.size;
                                        if (rect.contains(event.position)) {
                                          isInsideSDE = true;
                                        }
                                      }
                                    }
                                    if (!isInsideSDE) {
                                      bool isInsideTitle = false;
                                      final BuildContext? titleContext = _titleFocusNode.context;
                                      if (titleContext != null) {
                                        final RenderBox? box = titleContext.findRenderObject() as RenderBox?;
                                        if (box != null && box.hasSize) {
                                          final position = box.localToGlobal(Offset.zero);
                                          final rect = position & box.size;
                                          if (rect.contains(event.position)) {
                                            isInsideTitle = true;
                                          }
                                        }
                                      }
                                      if (!isInsideTitle) {
                                        _contentFocusNode.requestFocus();
                                        final len = _contentController.text.length;
                                        _contentController.selection =
                                            TextSelection.collapsed(offset: len);
                                      }
                                    }
                                  }
                                }
                              }
                              _pointerDownPos = null;
                            },
                            child: RepaintBoundary(
                              child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(
                                left: 24.0,
                                right: 24.0,
                                top: 59.0, // Date bar (50) + padding (9)
                                bottom: 120.0,
                              ),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent &&
                                          (event.logicalKey == LogicalKeyboardKey.enter ||
                                           event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                                        _focusContentArea();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: TextField(
                                      controller: _titleController,
                                      focusNode: _titleFocusNode,
                                      textCapitalization: TextCapitalization.sentences,
                                      maxLines: 1,
                                      textInputAction: TextInputAction.next,
                                      onEditingComplete: _focusContentArea,
                                      contextMenuBuilder: _buildContextMenu,
                                      scrollPadding: EdgeInsets.only(bottom: _getDynamicBottomScrollPadding()),
                                      style: GoogleFonts.inter(
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                        decoration: TextDecoration.none,
                                        height: 1.15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Title",
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor.withOpacity(0.3),
                                          height: 1.15,
                                          decoration: TextDecoration.none,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        filled: false,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _hasChanges = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  
                                  if (_isPreviewMarkdown)
                                    _buildMarkdownPreview(textColor)
                                  else if (NoteEditorScreen.useSingleDocumentEditor)
                                    SingleDocumentDragOverlay(
                                      controller: _contentController,
                                      sdeKey: _sdeKey,
                                      scrollController: _scrollController,
                                      isSelectionMode: true,
                                      child: NewSingleDocumentEditor(
                                        key: _sdeKey,
                                        controller: _contentController,
                                        focusNode: _contentFocusNode,
                                        textColor: textColor,
                                        paperGuideHeight: _paperGuideHeight,
                                        contextMenuBuilder: _buildContextMenu,
                                        formattingToolbarHeight: targetHeight,
                                        onBackspaceAtStart: _focusTitleArea,
                                      ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ...() {
                                          final List<Widget> list = [];
                                          for (int i = 0; i < _blocks.length; i++) {
                                            list.add(_buildBlockWidget(_blocks[i], textColor, titleColor));
                                            if (i < _blocks.length - 1) {
                                              final spacing = _getSpacingBetween(_blocks[i], _blocks[i + 1]);
                                              list.add(SizedBox(height: spacing));
                                            }
                                          }
                                          return list;
                                        }(),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            ),
                          ),
                        ),

                        // Sticky Yellow Header with Blur
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 50.0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30.0),
                              topRight: Radius.circular(30.0),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Container(
                                color: const Color(0xFFFFCC00).withOpacity(0.9),
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF1C1C1E),
                                        letterSpacing: -0.43,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF1C1C1E),
                                        letterSpacing: -0.43,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Backdrop Overlay for Morphing Options Popup
            IgnorePointer(
              ignoring: !_isNoteOptionsOpen,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _isNoteOptionsOpen ? 500 : 415),
                curve: Curves.easeOutCubic,
                opacity: _isNoteOptionsOpen ? 1.0 : 0.0,
                child: GestureDetector(
                  onTap: () => setState(() => _isNoteOptionsOpen = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.20),
                  ),
                ),
              ),
            ),

            // 3. Unified Top Header Overlay
            Positioned(
              top: 12.0,
              left: 24.0,
              right: 24.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: (notesProvider.isZenModeEnabled && _isZenTyping) ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: notesProvider.isZenModeEnabled && _isZenTyping,
                  child: AppHeaderBar(
                    isExpanded: _isNoteOptionsOpen,
                    expandedWidth: 192.0,
                    expandedHeight: 200.0,
                    expandedChild: NoteEditorOptionsPopup(
                      isPinned: _isPinned,
                      isFavorite: _isFavorite,
                      onTogglePin: () {
                        setState(() {
                          _isNoteOptionsOpen = false;
                          _isPinned = !_isPinned;
                          _hasChanges = true;
                        });
                      },
                      onToggleFavorite: () {
                        setState(() {
                          _isNoteOptionsOpen = false;
                          _isFavorite = !_isFavorite;
                          _hasChanges = true;
                        });
                      },
                      onExportAndShare: () {
                        setState(() => _isNoteOptionsOpen = false);
                        _showExportDialog();
                      },
                      onDeleteNote: _onDeleteNoteSelected,
                    ),
                    leftWidth: 44.0,
                    onLeftTap: () {
                      if (_isNoteOptionsOpen) {
                        setState(() => _isNoteOptionsOpen = false);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    leftChild: SvgPicture.asset(
                      'assets/icons/angle_left.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                    ),
                rightWidth: 192.0,
                rightChild: Row(
                  children: [
                    // Undo Button
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentController,
                        builder: (context, val, _) {
                          final canUndo = _contentController.canUndo;
                          return TactileButton(
                            useAppleSpring: true,
                            compressionScale: 0.7,
                            settleDuration: const Duration(milliseconds: 1000),
                            onTap: canUndo ? () {
                              _contentController.undo();
                              _restoreContentFocus();
                              setState(() {
                                _hasChanges = true;
                              });
                            } : () {},
                            child: Center(
                              child: Icon(
                                Icons.undo_rounded,
                                size: 22,
                                color: canUndo ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.3),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Redo Button
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _contentController,
                        builder: (context, val, _) {
                          final canRedo = _contentController.canRedo;
                          return TactileButton(
                            useAppleSpring: true,
                            compressionScale: 0.7,
                            settleDuration: const Duration(milliseconds: 1000),
                            onTap: canRedo ? () {
                              _contentController.redo();
                              _restoreContentFocus();
                              setState(() {
                                _hasChanges = true;
                              });
                            } : () {},
                            child: Center(
                              child: Icon(
                                Icons.redo_rounded,
                                size: 22,
                                color: canRedo ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.3),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Separator line
                    Container(
                      width: 1.0,
                      height: 18.0,
                      color: const Color(0xFF1C1C1E).withOpacity(0.15),
                    ),
                    // Folder Select Button
                    Expanded(
                      child: TactileButton(
                        useAppleSpring: true,
                        compressionScale: 0.7,
                        settleDuration: const Duration(milliseconds: 1000),
                        onTap: () {
                          _showFolderSelectorDialog();
                        },
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/bottom_navigation/folder-open.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                    // Options Button
                    Expanded(
                      child: TactileButton(
                        useAppleSpring: true,
                        compressionScale: 0.7,
                        settleDuration: const Duration(milliseconds: 1000),
                        onTap: () {
                          setState(() {
                            _isNoteOptionsOpen = !_isNoteOptionsOpen;
                          });
                        },
                        child: const Center(
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            
            AnimatedPositioned(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.elasticOut,
                bottom: 12,
                left: targetLeft,
                width: targetWidth,
                height: targetHeight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  opacity: (notesProvider.isZenModeEnabled && _isZenTyping) ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: notesProvider.isZenModeEnabled && _isZenTyping,
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                          if (_activeCategory != _ActiveCategory.none) {
                            setState(() {
                              _activeCategory = _ActiveCategory.none;
                            });
                          }
                        }
                      },
                  child: RichTextFormattingPillContainer(
                    width: targetWidth,
                    height: targetHeight,
                    borderRadius: _activeCategory != _ActiveCategory.none
                        ? BorderRadius.circular(30.0)
                        : null,
                    child: !_isFormattingBarExpanded
                        ? TactileButton(
                            useAppleSpring: true,
                            compressionScale: 0.7,
                            settleDuration: const Duration(milliseconds: 1000),
                            pressDuration: const Duration(milliseconds: 80),
                            playSelectionHaptic: true,
                            onTap: () {
                              setState(() {
                                _isFormattingBarExpanded = true;
                              });
                            },
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFF333333),
                                size: 24,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.elasticOut,
                                  tween: Tween<double>(
                                    begin: _activeCategory != _ActiveCategory.none ? 50.0 : 0.0,
                                    end: _activeCategory != _ActiveCategory.none ? 50.0 : 0.0,
                                  ),
                                  builder: (context, animHeight, child) {
                                    final clampedHeight = animHeight.clamp(0.0, double.infinity);
                                    return SizedBox(
                                      height: clampedHeight,
                                      child: ClipRect(
                                        child: clampedHeight > 0.0 ? child : const SizedBox.shrink(),
                                      ),
                                    );
                                  },
                                  child: _activeCategory != _ActiveCategory.none
                                      ? _buildSubsectionRow(activeStyle, _focusedBlock)
                                      : const SizedBox.shrink(),
                                ),
                                SizedBox(
                                  height: 50.0,
                                  child: _buildCategoriesRow(activeStyle),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
            
            // Custom Delete Popup
            if (_showDeletePopup)
              _buildDeletePopup(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsectionRow(Style activeStyle, NoteBlock? block) {
    Widget child;
    switch (_activeCategory) {
      case _ActiveCategory.aa:
        child = _buildAaSubsection(activeStyle);
        break;
      case _ActiveCategory.alignment:
        child = _buildAlignmentSubsection(activeStyle);
        break;
      case _ActiveCategory.list:
        child = _buildListSubsection(block);
        break;
      case _ActiveCategory.attachment:
        child = _buildAttachmentSubsection();
        break;
      case _ActiveCategory.headings:
        child = _buildHeadingsSubsection(block);
        break;
      default:
        child = const SizedBox.shrink();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_activeCategory),
        child: child,
      ),
    );
  }

  Widget _buildCategoriesRow(Style activeStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Left Page Arrow
        _buildCategoryIconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 24),
          onTap: () {
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          isActive: false,
          isEnabled: _currentPage > 0,
        ),
        
        // Sliding Categories
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildCategorySelectionPage(),
              _buildCategoryPage1(activeStyle),
              _buildCategoryPage2(),
            ],
          ),
        ),

        // Right Page Arrow
        _buildCategoryIconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 24),
          onTap: () {
            if (_currentPage < 2) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          isActive: false,
          isEnabled: _currentPage < 2,
        ),
      ],
    );
  }

  Widget _buildCategorySelectionPage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.content_cut_rounded,
            size: 22,
          ),
          onTap: _onCutSelectedText,
          isActive: false,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.copy_rounded,
            size: 22,
          ),
          onTap: _onCopySelectedText,
          isActive: false,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.select_all_rounded,
            size: 22,
          ),
          onTap: _onSelectAllText,
          isActive: false,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 22,
          ),
          onTap: _onDeleteSelectedText,
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildSubsectionIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
    required String tooltip,
  }) {
    final inactiveColor = const Color(0xFF333333);
    final activeColor = _tintColor;
    final activeBgColor = activeColor.withValues(alpha: 0.15);

    return Tooltip(
      message: tooltip,
      child: TactileButton(
        useAppleSpring: true,
        compressionScale: 0.7,
        settleDuration: const Duration(milliseconds: 1000),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? activeBgColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSubsectionTextButton({
    required String text,
    required VoidCallback onTap,
    required bool isActive,
    required TextStyle style,
    required String tooltip,
  }) {
    final inactiveColor = const Color(0xFF333333);
    final activeColor = _tintColor;
    final activeBgColor = activeColor.withValues(alpha: 0.15);

    return Tooltip(
      message: tooltip,
      child: TactileButton(
        useAppleSpring: true,
        compressionScale: 0.7,
        settleDuration: const Duration(milliseconds: 1000),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? activeBgColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            text,
            style: style.copyWith(
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAaSubsection(Style activeStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubsectionTextButton(
          text: "B",
          onTap: () => _wrapSelection('**', '**'),
          isActive: activeStyle.bold,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tooltip: 'Bold',
        ),
        _buildSubsectionTextButton(
          text: "I",
          onTap: () => _wrapSelection('*', '*'),
          isActive: activeStyle.italic,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
          tooltip: 'Italic',
        ),
        _buildSubsectionTextButton(
          text: "U",
          onTap: () => _wrapSelection('<u>', '</u>'),
          isActive: activeStyle.underline,
          style: GoogleFonts.inter(
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
          tooltip: 'Underline',
        ),
        _buildSubsectionTextButton(
          text: "T",
          onTap: () => _wrapSelection('~~', '~~'),
          isActive: activeStyle.strikethrough,
          style: GoogleFonts.inter(
            fontSize: 16,
            decoration: TextDecoration.lineThrough,
          ),
          tooltip: 'Strikethrough',
        ),
      ],
    );
  }

  Widget _buildAlignmentSubsection(Style activeStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubsectionIconButton(
          icon: Icons.format_align_left_rounded,
          onTap: () => _wrapSelection('<p align="left">', '</p>'),
          isActive: activeStyle.align == TextAlign.left,
          tooltip: 'Align Left',
        ),
        _buildSubsectionIconButton(
          icon: Icons.format_align_center_rounded,
          onTap: () => _wrapSelection('<p align="center">', '</p>'),
          isActive: activeStyle.align == TextAlign.center,
          tooltip: 'Align Center',
        ),
        _buildSubsectionIconButton(
          icon: Icons.format_align_right_rounded,
          onTap: () => _wrapSelection('<p align="right">', '</p>'),
          isActive: activeStyle.align == TextAlign.right,
          tooltip: 'Align Right',
        ),
        _buildSubsectionIconButton(
          icon: Icons.format_align_justify_rounded,
          onTap: () => _wrapSelection('<p align="justify">', '</p>'),
          isActive: activeStyle.align == TextAlign.justify,
          tooltip: 'Align Justify',
        ),
      ],
    );
  }

  Widget _buildListSubsection(NoteBlock? block) {
    // In SDE, read active style from the content controller; fall back to
    // legacy block inspection when useSingleDocumentEditor is false.
    final Style activeListStyle = NoteEditorScreen.useSingleDocumentEditor
        ? _contentController.currentActiveStyle
        : const Style();
    final bool isBullet = NoteEditorScreen.useSingleDocumentEditor
        ? activeListStyle.listType == 'bullet'
        : block is BulletedListBlock;
    final bool isNumber = NoteEditorScreen.useSingleDocumentEditor
        ? activeListStyle.listType == 'number'
        : block is NumberedListBlock;
    final bool isCheckbox = NoteEditorScreen.useSingleDocumentEditor
        ? activeListStyle.listType == 'checkbox'
        : block is ChecklistBlock;
    final bool isQuote = NoteEditorScreen.useSingleDocumentEditor
        ? activeListStyle.listType == 'quote'
        : block is QuoteBlock;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubsectionIconButton(
          icon: Icons.format_list_bulleted_rounded,
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('bullet');
              _restoreContentFocus();
            } else if (block != null) {
              isBullet
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, BulletedListBlock);
            }
          },
          isActive: isBullet,
          tooltip: 'Bullet List',
        ),
        _buildSubsectionIconButton(
          icon: Icons.format_list_numbered_rounded,
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('number');
              _restoreContentFocus();
            } else if (block != null) {
              isNumber
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, NumberedListBlock);
            }
          },
          isActive: isNumber,
          tooltip: 'Numbered List',
        ),
        _buildSubsectionIconButton(
          icon: Icons.add_task_rounded,
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('checkbox');
              _restoreContentFocus();
            } else if (block != null) {
              isCheckbox
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, ChecklistBlock);
            }
          },
          isActive: isCheckbox,
          tooltip: 'Checklist',
        ),
        _buildSubsectionIconButton(
          icon: Icons.format_quote_rounded,
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('quote');
              _restoreContentFocus();
            } else if (block != null) {
              isQuote
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, QuoteBlock);
            }
          },
          isActive: isQuote,
          tooltip: 'Quote Block',
        ),
      ],
    );
  }

  Widget _buildAttachmentSubsection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubsectionIconButton(
          icon: Icons.link_rounded,
          onTap: () => _wrapSelection('[', '](url)'),
          isActive: false,
          tooltip: 'Link',
        ),
        _buildSubsectionIconButton(
          icon: Icons.camera_alt_outlined,
          onTap: () {
            if (kImageDebug) {
              debugPrint("[Stage 1] Started");
              debugPrint("Relevant state: selection=${_contentController.selection}, styledChars length=${_contentController.styledChars.length}");
            }
            _showGalleryBottomSheet(context);
            if (kImageDebug) {
              debugPrint("[Stage 1] Completed");
            }
          },
          isActive: false,
          tooltip: 'Attach Image',
        ),
        _buildSubsectionIconButton(
          icon: Icons.horizontal_rule_rounded,
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.insertDivider();
              _restoreContentFocus();
              setState(() { _hasChanges = true; });
            }
          },
          isActive: false,
          tooltip: 'Insert Divider',
        ),
        _buildSubsectionIconButton(
          icon: Icons.mic_none_rounded,
          onTap: _startRecording,
          isActive: false,
          tooltip: 'Record Audio',
        ),
      ],
    );
  }

  Widget _buildHeadingsSubsection(NoteBlock? block) {
    // In SDE, derive heading state from the content controller's active style.
    final Style activeHeadStyle = NoteEditorScreen.useSingleDocumentEditor
        ? _contentController.currentActiveStyle
        : const Style();
    final bool isH1 = NoteEditorScreen.useSingleDocumentEditor
        ? activeHeadStyle.heading == 'h1'
        : block is HeadingBlock && block.level == 1;
    final bool isH2 = NoteEditorScreen.useSingleDocumentEditor
        ? activeHeadStyle.heading == 'h2'
        : block is HeadingBlock && block.level == 2;
    final bool isH3 = NoteEditorScreen.useSingleDocumentEditor
        ? activeHeadStyle.heading == 'h3'
        : block is HeadingBlock && block.level == 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubsectionTextButton(
          text: "H1",
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('h1');
              _restoreContentFocus();
            } else if (block != null) {
              isH1
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, HeadingBlock, headingLevel: 1);
            }
          },
          isActive: isH1,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
          tooltip: 'Heading 1',
        ),
        _buildSubsectionTextButton(
          text: "H2",
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('h2');
              _restoreContentFocus();
            } else if (block != null) {
              isH2
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, HeadingBlock, headingLevel: 2);
            }
          },
          isActive: isH2,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
          tooltip: 'Heading 2',
        ),
        _buildSubsectionTextButton(
          text: "H3",
          onTap: () {
            if (NoteEditorScreen.useSingleDocumentEditor) {
              _contentController.toggleParagraphStyle('h3');
              _restoreContentFocus();
            } else if (block != null) {
              isH3
                  ? _toggleBlockType(block, ParagraphBlock)
                  : _toggleBlockType(block, HeadingBlock, headingLevel: 3);
            }
          },
          isActive: isH3,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
          tooltip: 'Heading 3',
        ),
      ],
    );
  }

  Widget _buildCategoryIconButton({
    required Widget icon,
    required VoidCallback onTap,
    required bool isActive,
    bool isEnabled = true,
  }) {
    final inactiveColor = const Color(0xFF333333);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.35,
      child: Tooltip(
        message: '',
        child: TactileButton(
          useAppleSpring: true,
          compressionScale: 0.7,
          settleDuration: const Duration(milliseconds: 1000),
          onTap: isEnabled ? onTap : () {},
          child: SizedBox(
            width: 44,
            height: 44,
            child: isActive
                ? GlassSurface(
                    borderRadius: BorderRadius.circular(22),
                    customTintColor: _tintColor,
                    child: Center(
                      child: IconTheme.merge(
                        data: const IconThemeData(
                          color: Colors.white,
                        ),
                        child: icon,
                      ),
                    ),
                  )
                : Center(
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: inactiveColor,
                      ),
                      child: icon,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPage1(Style activeStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCategoryIconButton(
          icon: Text(
            "Aa",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _activeCategory == _ActiveCategory.aa ? Colors.white : const Color(0xFF333333),
            ),
          ),
          onTap: () {
            setState(() {
              if (_activeCategory == _ActiveCategory.aa) {
                _activeCategory = _ActiveCategory.none;
              } else {
                _activeCategory = _ActiveCategory.aa;
              }
            });
          },
          isActive: _activeCategory == _ActiveCategory.aa,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.format_align_left_rounded,
            size: 22,
          ),
          onTap: () {
            setState(() {
              if (_activeCategory == _ActiveCategory.alignment) {
                _activeCategory = _ActiveCategory.none;
              } else {
                _activeCategory = _ActiveCategory.alignment;
              }
            });
          },
          isActive: _activeCategory == _ActiveCategory.alignment,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.add_task_rounded,
            size: 22,
          ),
          onTap: () {
            setState(() {
              if (_activeCategory == _ActiveCategory.list) {
                _activeCategory = _ActiveCategory.none;
              } else {
                _activeCategory = _ActiveCategory.list;
              }
            });
          },
          isActive: _activeCategory == _ActiveCategory.list,
        ),
        _buildCategoryIconButton(
          icon: const RichTextFormattingPillIcon(
            assetName: 'assets/icons/highlighter.svg',
            size: 22,
          ),
          onTap: () {
            _wrapSelection('highlight', '');
          },
          isActive: activeStyle.highlight != null,
        ),
        _buildCategoryIconButton(
          icon: const RichTextFormattingPillIcon(
            assetName: 'assets/icons/link.svg',
            size: 22,
          ),
          onTap: () {
            setState(() {
              if (_activeCategory == _ActiveCategory.attachment) {
                _activeCategory = _ActiveCategory.none;
              } else {
                _activeCategory = _ActiveCategory.attachment;
              }
            });
          },
          isActive: _activeCategory == _ActiveCategory.attachment,
        ),
      ],
    );
  }

  Widget _buildCategoryPage2() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.title_rounded,
            size: 22,
          ),
          onTap: () {
            setState(() {
              if (_activeCategory == _ActiveCategory.headings) {
                _activeCategory = _ActiveCategory.none;
              } else {
                _activeCategory = _ActiveCategory.headings;
              }
            });
          },
          isActive: _activeCategory == _ActiveCategory.headings,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.grid_on_rounded,
            size: 22,
          ),
          onTap: () {
            _showPaperSettingsBottomSheet();
          },
          isActive: false,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.keyboard_hide_rounded,
            size: 22,
          ),
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          isActive: false,
        ),
        _buildCategoryIconButton(
          icon: const Icon(
            Icons.unfold_less_rounded,
            size: 22,
          ),
          onTap: () {
            setState(() {
              _isFormattingBarExpanded = false;
            });
          },
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildDeletePopup() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: Container(
            width: 262,
            height: 156,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 1),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  top: 18,
                  width: 231,
                  height: 83,
                  child: Center(
                    child: Text(
                      "Are you sure",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 35,
                  top: 101,
                  width: 80,
                  height: 35,
                  child: GestureDetector(
                    onTap: () async {
                      final provider = Provider.of<NotesProvider>(context, listen: false);
                      if (widget.note != null) {
                        await provider.trashNote(widget.note!.id);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Delete",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 145,
                  top: 101,
                  width: 80,
                  height: 35,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDeletePopup = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kImageDebug && NoteEditorScreen.useSingleDocumentEditor) {
      debugPrint("[Stage 7] Started");
      debugPrint("Relevant state: text length=${_contentController.text.length}, selection=${_contentController.selection}, scrollOffset=${_scrollController.hasClients ? _scrollController.offset : 'null'}");
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Always show active editor screen as the home screen handles the starting visual style
    Widget body = _buildActiveEditorScreen(theme, isDark);

    if (_isRecording) {
      body = Stack(
        children: [
          body,
          Positioned(
            left: 24,
            right: 24,
            bottom: 110,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red),
                  const SizedBox(width: 12),
                  Text(
                    "Recording: ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}",
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _stopRecording,
                    style: TextButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("STOP"),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (kImageDebug && NoteEditorScreen.useSingleDocumentEditor) {
      debugPrint("[Stage 7] Completed");
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: body,
    );
  }

  // Quick addition features popup
  void _showQuickAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mic_none_rounded),
                title: const Text("Record Voice Note"),
                onTap: () {
                  Navigator.pop(context);
                  _startRecording();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text("Attach Image"),
                onTap: () {
                  Navigator.pop(context);
                  _showGalleryBottomSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm_add_rounded),
                title: const Text("Set Reminder Alarm"),
                onTap: () {
                  Navigator.pop(context);
                  _pickReminder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.tag_rounded),
                title: const Text("Add Note Tag"),
                onTap: () {
                  Navigator.pop(context);
                  _showAddTagDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Note Tag"),
        content: TextField(
          controller: _tagController,
          decoration: const InputDecoration(hintText: "Enter tag (e.g. urgent)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addTag();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }



  // Markdown renderer viewer
  Widget _buildMarkdownPreview(Color textColor) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: _blocks.map((b) => b.toMarkdown()).join('\n'),
      selectable: true,
      imageBuilder: (uri, title, alt) {
        final cleanUri = uri.hasQuery ? uri.replace(queryParameters: {}) : uri;
        final path = cleanUri.scheme == 'file' ? cleanUri.toFilePath() : cleanUri.toString();
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              buildPageRoute(FullScreenImageViewer(imagePath: path)),
            );
          },
          child: Hero(
            tag: 'markdown_img_$path',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: uri.scheme == 'file'
                  ? Image.file(
                      File(path),
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    )
                  : Image.network(
                      path,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: GoogleFonts.inter(fontSize: 18.0, color: textColor, height: 1.6),
        h1: GoogleFonts.outfit(fontSize: 24.0, fontWeight: FontWeight.bold, color: textColor),
        h2: GoogleFonts.outfit(fontSize: 22.0, fontWeight: FontWeight.bold, color: textColor),
        h3: GoogleFonts.outfit(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  void _showFolderSelectorDialog() {
    showBlurredBottomSheet(
      context: context,
      child: FolderSelectionSheet(
        currentFolderId: _folderId,
        onFolderSelected: (folderId) {
          setState(() {
            _folderId = folderId;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _showExportDialog() {
    final tempNote = Note(
      id: widget.note?.id ?? 'temp',
      title: _titleController.text.trim(),
      content: NoteEditorScreen.useSingleDocumentEditor
          ? generateMarkdownFromStyledChars(_contentController.styledChars).trim()
          : _blocks.map((b) => b.toMarkdown()).join('\n').trim(),
      tags: _tags,
      attachments: _attachments,
      category: _category,
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      isArchived: _isArchived,
      isLocked: _isLocked,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      colorValue: _colorIndex,
      folderId: _folderId,
      isHabit: _isHabit,
      habitRecurrence: _habitRecurrence,
    );
    showDialog(
      context: context,
      builder: (context) => ExportDialog(note: tempNote),
    );
  }

  void _showHabitSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text("Habit Settings", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Track as Habit"),
                    value: _isHabit,
                    onChanged: (val) {
                      setState(() {
                        _isHabit = val;
                        if (!val) {
                          _habitRecurrence = 'none';
                        } else if (_habitRecurrence == 'none') {
                          _habitRecurrence = 'daily';
                        }
                        _hasChanges = true;
                      });
                      setDialogState(() {});
                    },
                  ),
                  if (_isHabit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Reset Interval", border: OutlineInputBorder()),
                      dropdownColor: theme.colorScheme.surface,
                      initialValue: _habitRecurrence == 'none' ? 'daily' : _habitRecurrence,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text("Daily Reset")),
                        DropdownMenuItem(value: 'weekly', child: Text("Weekly Reset")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _habitRecurrence = val;
                            _hasChanges = true;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetupPinDialog() {
    final theme = Theme.of(context);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text("Setup Secure PIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "Enter 4-digit PIN", border: OutlineInputBorder(), counterText: ""),
                  validator: (value) {
                    if (value == null || value.length != 4 || int.tryParse(value) == null) {
                      return "Enter exactly 4 digits";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "Confirm PIN", border: OutlineInputBorder(), counterText: ""),
                  validator: (value) {
                    if (value != pinController.text) {
                      return "PINs do not match";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await VaultService.instance.setVaultPin(pinController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _isLocked = true;
                      _hasChanges = true;
                    });
                  }
                }
              },
              child: const Text("Save & Lock"),
            ),
          ],
        );
      },
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;

  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isFile = !imagePath.startsWith('http://') && !imagePath.startsWith('https://');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'markdown_img_$imagePath',
            child: isFile
                ? Image.file(
                    File(imagePath),
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  )
                : Image.network(
                    imagePath,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

abstract class NoteBlock {
  final String id;
  NoteBlock({required this.id});
  String toMarkdown();
}

class ParagraphBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;

  ParagraphBlock({required super.id, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    return generateMarkdownFromStyledChars(controller.styledChars).trim();
  }
}

class HeadingBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;
  final int level; // 1, 2, 3

  HeadingBlock({required super.id, required this.level, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    final prefix = '#' * level + ' ';
    final content = generateMarkdownFromStyledChars(controller.styledChars).trim();
    return '$prefix$content';
  }
}

class QuoteBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;

  QuoteBlock({required super.id, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    final content = generateMarkdownFromStyledChars(controller.styledChars).trim();
    return '> $content';
  }
}

class ChecklistBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;
  bool isChecked;

  ChecklistBlock({required super.id, required this.isChecked, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    final prefix = isChecked ? '- [x] ' : '- [ ] ';
    final content = generateMarkdownFromStyledChars(controller.styledChars).trim();
    return '$prefix$content';
  }
}

class BulletedListBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;

  BulletedListBlock({required super.id, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    final content = generateMarkdownFromStyledChars(controller.styledChars).trim();
    return '- $content';
  }
}

class NumberedListBlock extends NoteBlock {
  final RichTextEditingController controller;
  final FocusNode focusNode;

  NumberedListBlock({required super.id, String markdown = ""})
      : controller = RichTextEditingController(markdown: markdown),
        focusNode = FocusNode();

  @override
  String toMarkdown() {
    final content = generateMarkdownFromStyledChars(controller.styledChars).trim();
    return '1. $content';
  }
}

class ImageBlock extends NoteBlock {
  final String imageUrl;
  double? width;
  String? caption;

  ImageBlock({
    required super.id,
    required this.imageUrl,
    this.width,
    this.caption,
  });

  @override
  String toMarkdown() {
    final altText = caption ?? 'Image';
    final urlBuffer = StringBuffer(imageUrl);
    if (width != null) {
      urlBuffer.write('?width=${width!.toInt()}');
    }
    return '![$altText](${urlBuffer.toString()})';
  }
}

class DividerBlock extends NoteBlock {
  DividerBlock({required super.id});

  @override
  String toMarkdown() {
    return '---';
  }
}

class ImageStackBlock extends NoteBlock {
  final List<ImageBlock> images;

  ImageStackBlock({required super.id, required this.images});

  @override
  String toMarkdown() {
    return images.map((img) => img.toMarkdown()).join('\n');
  }
}

class ImageStackWidget extends StatefulWidget {
  final ImageStackBlock block;
  final Color textColor;
  final Color titleColor;
  final int index;
  final VoidCallback onUpdate;
  final Function(ImageBlock) onDeleteImage;
  final Function(ImageBlock, int) onReplaceImage;

  const ImageStackWidget({
    super.key,
    required this.block,
    required this.textColor,
    required this.titleColor,
    required this.index,
    required this.onUpdate,
    required this.onDeleteImage,
    required this.onReplaceImage,
  });

  @override
  State<ImageStackWidget> createState() => _ImageStackWidgetState();
}

class _ImageStackWidgetState extends State<ImageStackWidget> {
  @override
  Widget build(BuildContext context) {
    final images = widget.block.images;
    final List<Widget> children = [];

    if (images.length == 2) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItem(images[0], 0)),
            const SizedBox(width: 8),
            Expanded(child: _buildItem(images[1], 1)),
          ],
        ),
      );
    } else if (images.length == 3) {
      children.add(_buildItem(images[0], 0));
      children.add(const SizedBox(height: 8));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItem(images[1], 1)),
            const SizedBox(width: 8),
            Expanded(child: _buildItem(images[2], 2)),
          ],
        ),
      );
    } else if (images.length == 4) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItem(images[0], 0)),
            const SizedBox(width: 8),
            Expanded(child: _buildItem(images[1], 1)),
          ],
        ),
      );
      children.add(const SizedBox(height: 8));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildItem(images[2], 2)),
            const SizedBox(width: 8),
            Expanded(child: _buildItem(images[3], 3)),
          ],
        ),
      );
    } else {
      for (int i = 0; i < images.length; i += 2) {
        if (i > 0) {
          children.add(const SizedBox(height: 8));
        }
        if (i + 1 < images.length) {
          children.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildItem(images[i], i)),
                const SizedBox(width: 8),
                Expanded(child: _buildItem(images[i + 1], i + 1)),
              ],
            ),
          );
        } else {
          children.add(_buildItem(images[i], i));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildItem(ImageBlock img, int stackImageIndex) {
    return ResizableImageWidget(
      key: ValueKey(img.id),
      imagePath: img.imageUrl,
      initialWidth: img.width,
      caption: img.caption,
      index: widget.index,
      isStacked: true,
      stackImageIndex: stackImageIndex,
      onUpdate: (newWidth, newCaption) {
        setState(() {
          img.width = newWidth;
          img.caption = newCaption;
        });
        widget.onUpdate();
      },
      onDelete: () {
        widget.onDeleteImage(img);
      },
      onReplace: () {
        widget.onReplaceImage(img, stackImageIndex);
      },
    );
  }
}

