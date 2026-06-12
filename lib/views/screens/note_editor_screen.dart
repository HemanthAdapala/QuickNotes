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
import '../../providers/notes_provider.dart';
import '../../services/vault_service.dart';
import '../widgets/folder_selector_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/rich_text_controller.dart';
import 'package:flutter/services.dart';
import 'dart:math';


class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String defaultCategory;
  final String defaultNoteType;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.defaultCategory = 'Uncategorized',
    this.defaultNoteType = 'text',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  late final TextEditingController _contentController;
  final _tagController = TextEditingController();
  List<NoteBlock> _blocks = [];
  int _nextIdCounter = 0;
  NoteBlock? _lastFocusedBlock;

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
        for (final block in _blocks) {
          if (_getFocusNodeOfBlock(block) == focusNode) {
            _lastFocusedBlock = block;
            break;
          }
        }
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
    return null;
  }

  FocusNode? _getFocusNodeOfBlock(NoteBlock block) {
    if (block is ParagraphBlock) return block.focusNode;
    if (block is HeadingBlock) return block.focusNode;
    if (block is QuoteBlock) return block.focusNode;
    if (block is ChecklistBlock) return block.focusNode;
    return null;
  }

  void _onBlockTextChanged(NoteBlock block) {
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

    if (block is ChecklistBlock && controller.text.isEmpty) {
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
    if (block is ChecklistBlock && block.controller.text.isEmpty) {
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
    final isCurrentText = current is ParagraphBlock || current is HeadingBlock || current is QuoteBlock;
    final isNextText = next is ParagraphBlock || next is HeadingBlock || next is QuoteBlock;
    
    final isCurrentChecklist = current is ChecklistBlock;
    final isNextChecklist = next is ChecklistBlock;
    
    final isCurrentMedia = current is ImageBlock || current is ImageStackBlock;
    final isNextMedia = next is ImageBlock || next is ImageStackBlock;

    if (isCurrentText && isNextText) {
      return 6.0; // Paragraph ↔ Paragraph: 6px
    }
    if ((isCurrentText && isNextChecklist) || (isCurrentChecklist && isNextText)) {
      return 6.0; // Paragraph ↔ Checklist: 6px
    }
    if (isCurrentChecklist && isNextChecklist) {
      return 3.0; // Checklist item ↔ Checklist item: 3px
    }
    if ((isCurrentMedia && !isNextMedia) || (!isCurrentMedia && isNextMedia)) {
      return 14.0; // Media ↔ Any text/checklist block: 14px
    }
    if (isCurrentMedia && isNextMedia) {
      return 14.0;
    }
    if (current is DividerBlock || next is DividerBlock) {
      return 10.0;
    }
    return 4.0;
  }

  Widget _buildBlockWidget(NoteBlock block, Color textColor, Color titleColor) {
    final blockWidget = _buildRawBlockWidget(block, textColor, titleColor);

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
          textAlign: block.controller.styledChars.isNotEmpty
              ? block.controller.styledChars.first.style.align
              : TextAlign.left,
          style: GoogleFonts.inter(
            fontSize: 18.0,
            color: textColor,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText: _blocks.indexOf(block) == 0 && _blocks.length == 1 ? "Start writing..." : "",
            hintStyle: GoogleFonts.inter(
              fontSize: 18.0,
              color: textColor.withAlpha(80),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            filled: false,
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
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: titleColor,
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
            style: GoogleFonts.inter(
              fontSize: 18.0,
              color: textColor.withAlpha(220),
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: "Quote",
              hintStyle: GoogleFonts.inter(
                fontSize: 18.0,
                color: textColor.withAlpha(80),
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
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
            Checkbox(
              value: block.isChecked,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool? val) {
                setState(() {
                  block.isChecked = val ?? false;
                  _hasChanges = true;
                });
              },
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
                  style: GoogleFonts.inter(
                    fontSize: 16.0,
                    color: block.isChecked ? textColor.withAlpha(120) : textColor,
                    decoration: block.isChecked ? TextDecoration.lineThrough : null,
                  ),
                  decoration: const InputDecoration(
                    hintText: "To-do item",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
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
  final _pageController = PageController();
  int _currentPage = 0;
  
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  String _category = 'Uncategorized';
  String _noteType = 'text'; // 'text' or 'checklist'
  bool _isLocked = false;
  DateTime? _reminderTime;

  List<String> _tags = [];
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _checklistItems = []; // [{'text': '...', 'done': false}]
  List<TextEditingController> _checklistControllers = [];

  // Folders & Habits state
  String? _folderId;
  bool _isHabit = false;
  String _habitRecurrence = 'none';
  int _habitStreak = 0;
  DateTime? _habitLastCompleted;

  bool _hasChanges = false;
  bool _isPreviewMarkdown = false;
  bool _isPageSettled = false;
  int _wordCount = 0;
  int _charCount = 0;
  bool _isSaving = false;

  // Zen Focus Mode state
  Timer? _zenTimer;
  bool _isZenTyping = false;

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
      
      if (_noteType == 'checklist') {
        try {
          final decoded = jsonDecode(widget.note!.content) as List<dynamic>;
          _checklistItems = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (e) {
          _checklistItems = [];
        }
        _checklistControllers = _checklistItems.map((item) => TextEditingController(text: item['text'] ?? "")).toList();
        _contentController = TextEditingController();
      } else {
        _contentController = TextEditingController();
        _blocks = parseMarkdownToBlocks(widget.note!.content);
      }
    } else {
      _category = widget.defaultCategory;
      _noteType = widget.defaultNoteType;
      _folderId = null;
      _isHabit = false;
      _habitRecurrence = 'none';
      _habitStreak = 0;
      _habitLastCompleted = null;

      if (_noteType == 'text') {
        _contentController = TextEditingController();
        final firstBlock = ParagraphBlock(id: _generateId());
        _setupBlockFocusNode(firstBlock.focusNode);
        _setupBlockController(firstBlock);
        _blocks = [firstBlock];
      } else {
        _contentController = TextEditingController();
      }
    }
    _calculateCounts();

    _titleController.addListener(_onTitleTextChanged);
    _contentController.addListener(_onContentTextChanged);
    
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
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          if (mounted) {
            setState(() {
              _isPageSettled = true;
            });
            if (widget.note == null && _noteType == 'text' && _blocks.isNotEmpty) {
              final firstBlock = _blocks.first;
              if (firstBlock is ParagraphBlock) {
                firstBlock.focusNode.requestFocus();
              }
            }
          }
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              route.animation!.removeStatusListener(listener);
              if (mounted) {
                setState(() {
                  _isPageSettled = true;
                });
                if (widget.note == null && _noteType == 'text' && _blocks.isNotEmpty) {
                  final firstBlock = _blocks.first;
                  if (firstBlock is ParagraphBlock) {
                    firstBlock.focusNode.requestFocus();
                  }
                }
              }
            }
          }
          route.animation!.addStatusListener(listener);
        }
      } else {
        if (mounted) {
          setState(() {
            _isPageSettled = true;
          });
          if (widget.note == null && _noteType == 'text' && _blocks.isNotEmpty) {
            final firstBlock = _blocks.first;
            if (firstBlock is ParagraphBlock) {
              firstBlock.focusNode.requestFocus();
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    _pageController.dispose();
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
      }
    }
    _recordTimer?.cancel();
    _zenTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
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
    });
  }

  void _onContentTextChanged() {
    _calculateCounts();
    _startZenTimer();
    setState(() {
      _hasChanges = true;
    });
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
    final block = _focusedBlock;
    if (block is ParagraphBlock) return block.controller;
    if (block is HeadingBlock) return block.controller;
    if (block is QuoteBlock) return block.controller;
    if (block is ChecklistBlock) return block.controller;
    return null;
  }

  bool get _anyBlockHasFocus {
    for (final block in _blocks) {
      final fn = _getFocusNodeOfBlock(block);
      if (fn != null && fn.hasFocus) return true;
    }
    return false;
  }

  void _calculateCounts() {
    String text = "";
    if (_noteType == 'checklist') {
      text = _checklistItems.map((e) => e['text'].toString()).join(" ");
    } else {
      text = _blocks.map((b) {
        if (b is ParagraphBlock) return b.controller.text;
        if (b is HeadingBlock) return b.controller.text;
        if (b is QuoteBlock) return b.controller.text;
        if (b is ChecklistBlock) return b.controller.text;
        return "";
      }).join(" ").trim();
    }
    setState(() {
      _charCount = text.length;
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  // --- Checklist operations ---
  void _syncControllers() {
    while (_checklistControllers.length < _checklistItems.length) {
      final index = _checklistControllers.length;
      final text = _checklistItems[index]['text'] ?? '';
      _checklistControllers.add(TextEditingController(text: text));
    }
    while (_checklistControllers.length > _checklistItems.length) {
      _checklistControllers.removeLast().dispose();
    }
    for (int i = 0; i < _checklistItems.length; i++) {
      final text = _checklistItems[i]['text'] ?? '';
      if (_checklistControllers[i].text != text) {
        _checklistControllers[i].text = text;
      }
    }
  }

  void _addChecklistItem() {
    _startZenTimer();
    setState(() {
      _checklistItems.add({'text': '', 'done': false});
      _checklistControllers.add(TextEditingController());
      _hasChanges = true;
      _calculateCounts();
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
      if (index < _checklistControllers.length) {
        _checklistControllers.removeAt(index).dispose();
      }
      _hasChanges = true;
      _calculateCounts();
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
                              Navigator.pop(context);
                              _insertSelectedImages(selectedPaths);
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
                                Navigator.pop(context);
                                final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                                if (picked != null) {
                                  _insertSelectedImages(['file://${picked.path}']);
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
                                Navigator.pop(context);
                                final pickedList = await _imagePicker.pickMultiImage();
                                if (pickedList.isNotEmpty) {
                                  _insertSelectedImages(pickedList.map((x) => 'file://${x.path}').toList());
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

  void _toggleNoteType() {
    setState(() {
      if (_noteType == 'text') {
        // Convert plain text to checklist
        final textContent = _blocks.map((b) => b.toMarkdown()).join('\n');
        final lines = textContent.split('\n');
        _checklistItems = lines
            .where((line) => line.trim().isNotEmpty)
            .map((line) {
              String cleanLine = line.trim();
              bool isDone = false;
              if (cleanLine.startsWith('- [ ]')) {
                cleanLine = cleanLine.substring(5).trim();
              } else if (cleanLine.startsWith('- [x]')) {
                cleanLine = cleanLine.substring(5).trim();
                isDone = true;
              } else if (cleanLine.startsWith('-')) {
                cleanLine = cleanLine.substring(1).trim();
              } else if (cleanLine.startsWith('\u2610')) {
                cleanLine = cleanLine.substring(1).trim();
              } else if (cleanLine.startsWith('\u2611')) {
                cleanLine = cleanLine.substring(1).trim();
                isDone = true;
              } else if (cleanLine.startsWith('•')) {
                cleanLine = cleanLine.substring(1).trim();
              }
              return {'text': cleanLine, 'done': isDone};
            })
            .toList();
        if (_checklistItems.isEmpty) {
          _checklistItems.add({'text': '', 'done': false});
        }
        for (final c in _checklistControllers) {
          c.dispose();
        }
        _checklistControllers = _checklistItems.map((item) => TextEditingController(text: item['text'] ?? "")).toList();
        _noteType = 'checklist';
      } else {
        // Convert checklist to plain text
        final text = _checklistItems.map((item) {
          final String prefix = item['done'] == true ? '- [x] ' : '- [ ] ';
          return '$prefix${item['text'] ?? ""}';
        }).join('\n');
        
        _blocks = parseMarkdownToBlocks(text);
        _noteType = 'text';
      }
      _hasChanges = true;
    });
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

  // --- Save Operations ---
  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final content = _noteType == 'checklist' 
          ? jsonEncode(_checklistItems) 
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
    }

    NoteBlock newBlock;
    final id = block.id;

    if (targetType == HeadingBlock) {
      newBlock = HeadingBlock(id: id, level: headingLevel ?? 1, markdown: "");
    } else if (targetType == QuoteBlock) {
      newBlock = QuoteBlock(id: id, markdown: "");
    } else if (targetType == ChecklistBlock) {
      newBlock = ChecklistBlock(id: id, isChecked: isChecked ?? false, markdown: "");
    } else if (targetType == DividerBlock) {
      newBlock = DividerBlock(id: id);
    } else {
      newBlock = ParagraphBlock(id: id, markdown: "");
    }

    if (newBlock is ParagraphBlock) {
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.text = text;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is HeadingBlock) {
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.text = text;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is QuoteBlock) {
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.text = text;
      newBlock.controller.selection = selection;
      _setupBlockFocusNode(newBlock.focusNode);
      _setupBlockController(newBlock);
    } else if (newBlock is ChecklistBlock) {
      newBlock.controller.styledChars = styledChars;
      newBlock.controller.text = text;
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
                icon: _noteType == 'text' ? Icons.playlist_add_check_rounded : Icons.text_snippet_rounded,
                label: _noteType == 'text' ? "Convert to Checklist" : "Convert to Plain Text",
                onTap: _toggleNoteType,
              ),
              if (_noteType == 'checklist')
                _buildCommandItem(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  label: "Configure Habit",
                  onTap: _showHabitSettingsDialog,
                ),
              _buildCommandItem(
                context,
                icon: Icons.share_rounded,
                label: "Export & Share",
                onTap: _showExportDialog,
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

  Widget _buildCategorySelector(Color titleColor) {
    final categories = NotesProvider.categories;
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
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary.withAlpha(40) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                icon,
                color: isActive ? theme.colorScheme.primary : buttonColor.withAlpha(200),
                size: 20,
              ),
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
                  // Page 0: Styles Group
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

                  // Page 1: Headings & Lists Group
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
                  ]),

                  // Page 2: Alignments & Actions Group
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
            opacity: _currentPage < 2 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 2,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Resolve note colors matching theme
    final editorBgColor = NotesProvider.getNoteColor(_colorIndex, context);
    final textColor = NotesProvider.getNoteTextColor(_colorIndex, context);
    final titleColor = NotesProvider.getNoteTitleColor(_colorIndex, context);

    final dateStr = DateFormat('MMM d, yyyy').format(widget.note?.updatedAt ?? DateTime.now());
    final readingTime = "${(_wordCount / 200).ceil()} min read";

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: editorBgColor,
        // AppBar (Faded in Zen Mode)
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AnimatedOpacity(
            opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_isPageSettled || _isZenTyping,
              child: AppBar(
                backgroundColor: editorBgColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  if (_noteType == 'text')
                    IconButton(
                      icon: Icon(
                        _isPreviewMarkdown ? Icons.menu_book_rounded : Icons.text_snippet_rounded,
                        color: titleColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPreviewMarkdown = !_isPreviewMarkdown;
                        });
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_open,
                      color: _isLocked ? theme.colorScheme.primary : titleColor,
                    ),
                    onPressed: () async {
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
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.star : Icons.star_border,
                      color: _isFavorite ? Colors.amber : titleColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                        _hasChanges = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Media attachments (fades in zen mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Column(
                    children: [
                      // Images slider
                      if (_attachments.any((a) => a['type'] == 'image'))
                        Container(
                          height: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _attachments.where((a) => a['type'] == 'image').map((image) {
                              final path = image['path'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(File(path), fit: BoxFit.cover, width: 90, height: 90),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _attachments.remove(image);
                                            _hasChanges = true;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      // Audio player panel
                      if (_attachments.any((a) => a['type'] == 'voice'))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: Column(
                            children: _attachments.where((a) => a['type'] == 'voice').map((voice) {
                              final path = voice['path'] as String;
                              final duration = voice['duration'] as int;
                              final isCurrent = _currentlyPlayingPath == path;
                              final playStatus = isCurrent && _isPlaying;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: titleColor.withAlpha(15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(playStatus ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                                      onPressed: () => _toggleAudioPlay(path),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Voice Attachment (${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')})",
                                        style: GoogleFonts.inter(fontSize: 13, color: textColor),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _attachments.remove(voice);
                                          _hasChanges = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Main Writing canvas
              Expanded(
                child: DragTarget<Map<String, dynamic>>(
                  onWillAcceptWithDetails: (details) => _noteType == 'text',
                  onAcceptWithDetails: (details) {
                    final data = details.data;
                    final oldIndex = data['oldIndex'] as int;
                    if (oldIndex != -1 && oldIndex < _blocks.length) {
                      setState(() {
                        final imgBlock = _blocks.removeAt(oldIndex);
                        _blocks.add(imgBlock);
                        _hasChanges = true;
                      });
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          sliver: SliverFillRemaining(
                            hasScrollBody: false,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 720),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Metadata Info row (Faded in Zen mode)
                                    AnimatedOpacity(
                                      opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                                      duration: const Duration(milliseconds: 300),
                                      child: IgnorePointer(
                                        ignoring: !_isPageSettled || _isZenTyping,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 16.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF91918E)),
                                              const SizedBox(width: 4),
                                              Text(
                                                dateStr,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF91918E)),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF91918E)),
                                              const SizedBox(width: 4),
                                              Text(
                                                readingTime,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF91918E)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
          
                                    // Note Title input
                                    TextField(
                                      controller: _titleController,
                                      maxLines: 1,
                                      style: GoogleFonts.outfit(
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Note Title",
                                        hintStyle: GoogleFonts.outfit(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor.withAlpha(80),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        filled: false,
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),
                                    _buildCategorySelector(titleColor),
                                    const SizedBox(height: 16.0),
          
                                    // Render Checklist mode OR Markdown body OR Text editor
                                    if (_noteType == 'checklist')
                                      _buildChecklistEditor(textColor)
                                    else if (_isPreviewMarkdown)
                                      _buildMarkdownPreview(textColor)
                                    else
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            DragTarget<Map<String, dynamic>>(
                                              onWillAcceptWithDetails: (details) => details.data['imagePath'] != null,
                                              onAcceptWithDetails: (details) {
                                                final data = details.data;
                                                final oldIndex = data['oldIndex'] as int;
                                                final stackImgIdx = data['stackImageIndex'] as int?;
                                                setState(() {
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
                                                  _blocks.insert(0, draggedImgBlock);
                                                  _hasChanges = true;
                                                });
                                              },
                                              builder: (context, candidateData, rejectedData) {
                                                final isHovered = candidateData.isNotEmpty;
                                                return GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => _insertParagraphAt(0),
                                                  child: Container(
                                                    height: isHovered ? 24.0 : 16.0,
                                                    color: isHovered ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                                                  ),
                                                );
                                              },
                                            ),
                                            ...() {
                                              final List<Widget> list = [];
                                              for (int i = 0; i < _blocks.length; i++) {
                                                list.add(_buildBlockWidget(_blocks[i], textColor, titleColor));
                                                
                                                if (i < _blocks.length - 1) {
                                                  final spacing = _getSpacingBetween(_blocks[i], _blocks[i + 1]);
                                                  list.add(
                                                    DragTarget<Map<String, dynamic>>(
                                                      onWillAcceptWithDetails: (details) => details.data['imagePath'] != null,
                                                      onAcceptWithDetails: (details) {
                                                        final data = details.data;
                                                        final oldIndex = data['oldIndex'] as int;
                                                        final stackImgIdx = data['stackImageIndex'] as int?;
                                                        setState(() {
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
                                                          int insertIdx = i + 1;
                                                          if (oldIndex < insertIdx && stackImgIdx == null) {
                                                            insertIdx--;
                                                          }
                                                          _blocks.insert(insertIdx, draggedImgBlock);
                                                          _hasChanges = true;
                                                        });
                                                      },
                                                      builder: (context, candidateData, rejectedData) {
                                                        final isHovered = candidateData.isNotEmpty;
                                                        return GestureDetector(
                                                          behavior: HitTestBehavior.opaque,
                                                          onTap: () => _insertParagraphAt(i + 1),
                                                          child: Container(
                                                            height: isHovered ? 24.0 : spacing,
                                                            color: isHovered ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  );
                                                }
                                              }
                                              return list;
                                            }(),
                                            Expanded(
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _insertParagraphAt(_blocks.length),
                                                child: const SizedBox(height: 100),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Tags Chip bar (Faded in Zen Mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Column(
                    children: [
                      if (_tags.isNotEmpty)
                        Container(
                          height: 32,
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            children: _tags.map((tag) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Chip(
                                  label: Text("#$tag"),
                                  labelStyle: GoogleFonts.inter(fontSize: 11, color: textColor),
                                  backgroundColor: titleColor.withAlpha(15),
                                  onDeleted: () {
                                    setState(() {
                                      _tags.remove(tag);
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom control panels (Fades in Zen mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Container(
                    padding: _anyBlockHasFocus && _noteType == 'text' && !_isPreviewMarkdown
                        ? const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0)
                        : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: _anyBlockHasFocus && _noteType == 'text' && !_isPreviewMarkdown
                          ? Colors.transparent
                          : editorBgColor,
                      border: _anyBlockHasFocus && _noteType == 'text' && !_isPreviewMarkdown
                          ? null
                          : Border(top: BorderSide(color: titleColor.withAlpha(20))),
                    ),
                    child: _anyBlockHasFocus && _noteType == 'text' && !_isPreviewMarkdown
                        ? _buildFormattingToolbar(textColor, titleColor)
                        : _buildStandardBottomPanel(editorBgColor, titleColor, textColor, theme),
                  ),
                ),
              ),

              // Audio Record overlay
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(24.0)),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        "Recording: ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}",
                        style: GoogleFonts.inter(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _stopRecording,
                        style: TextButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white),
                        child: const Text("STOP"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  ),
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

  // Checklist editor view builder
  Widget _buildChecklistEditor(Color textColor) {
    if (_checklistControllers.length != _checklistItems.length) {
      _syncControllers();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_checklistItems.length, (index) {
          final item = _checklistItems[index];
          final bool isDone = item['done'] ?? false;
          final TextEditingController itemController = _checklistControllers[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Checkbox(
                  value: isDone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? val) {
                    setState(() {
                      _checklistItems[index]['done'] = val ?? false;
                      _hasChanges = true;
                      _calculateCounts();
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: itemController,
                    onChanged: (val) {
                      _checklistItems[index]['text'] = val;
                      _hasChanges = true;
                      _calculateCounts();
                    },
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDone ? textColor.withAlpha(120) : textColor,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    decoration: const InputDecoration(
                      hintText: "List item",
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => _removeChecklistItem(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _addChecklistItem,
          icon: const Icon(Icons.add_rounded),
          label: Text("Add Item", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
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
              MaterialPageRoute(
                builder: (context) => FullScreenImageViewer(imagePath: path),
              ),
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
    showDialog(
      context: context,
      builder: (context) => FolderSelectorDialog(
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
      content: _noteType == 'checklist' ? jsonEncode(_checklistItems) : _blocks.map((b) => b.toMarkdown()).join('\n').trim(),
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

