import 'package:flutter/widgets.dart';
import '../../views/widgets/rich_text_controller.dart';
import '../../views/widgets/new_single_document_editor.dart';

abstract class ParagraphBlockBehavior {
  String get listType;
  bool hasPrefix(String text);
  int get prefixLen;
  StyledChar getPrefixChar(Style style);

  KeyEventResult handleEnterKey({
    required int segmentIndex,
    required RangeTextEditingController controller,
    required NewSingleDocumentEditorState editorState,
  }) {
    final selection = controller.selection;
    final text = controller.text;
    final range = controller.getRange();
    if (!range.isValid) return KeyEventResult.ignored;

    final caretOffset = selection.baseOffset;

    if (text.length == 1) {
      // Exit list / outdent
      final baseStyle =
          editorState.widget.controller.styledChars[range.start].style;
      final currentIndent = baseStyle.indent;
      if (currentIndent > 0) {
        editorState.changeIndent(segmentIndex, outdent: true);
        return KeyEventResult.handled;
      }

      final List<StyledChar> updated =
          List.from(editorState.widget.controller.styledChars);
      updated.removeAt(range.start);

      if (range.start < updated.length) {
        updated[range.start] = StyledChar(
          char: updated[range.start].char,
          style: updated[range.start]
              .style
              .copyWith(listType: 'normal', indent: 0),
        );
      }

      editorState.widget.controller.saveUndoState();
      editorState.widget.controller.styledChars = updated;
      editorState.widget.controller.currentActiveStyle =
          editorState.widget.controller.currentActiveStyle.copyWith(
        listType: 'normal',
        checked: false,
        indent: 0,
      );

      editorState.parseCurrentSegments();

      editorState.widget.controller.value = TextEditingValue(
        text: updated.map((sc) => sc.char).join(),
        selection: TextSelection.collapsed(offset: range.start),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        editorState.focusNodes[segmentIndex]?.requestFocus();
      });
      return KeyEventResult.handled;
    } else {
      // Continue list item
      final int insertIdx = range.start + caretOffset;
      final List<StyledChar> updated =
          List.from(editorState.widget.controller.styledChars);
      final baseStyle =
          editorState.widget.controller.styledChars[range.start].style;
      final listStyle =
          baseStyle.copyWith(checked: false, strikethrough: false);

      updated.insert(insertIdx, StyledChar(char: '\n', style: listStyle));
      updated.insert(insertIdx + 1, getPrefixChar(listStyle));

      editorState.widget.controller.saveUndoState();
      editorState.widget.controller.styledChars = updated;
      editorState.widget.controller.currentActiveStyle = listStyle;

      final newCursorOffset = insertIdx + 2;

      editorState.parseCurrentSegments();

      editorState.widget.controller.value = TextEditingValue(
        text: updated.map((sc) => sc.char).join(),
        selection: TextSelection.collapsed(offset: newCursorOffset),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nextTextSegIdx = segmentIndex + 1;
        editorState.focusNodes[nextTextSegIdx]?.requestFocus();
      });

      return KeyEventResult.handled;
    }
  }

  KeyEventResult handleBackspaceKey({
    required int segmentIndex,
    required RangeTextEditingController controller,
    required NewSingleDocumentEditorState editorState,
  }) {
    final text = controller.text;
    final range = controller.getRange();
    if (!range.isValid) return KeyEventResult.ignored;

    if (text.length == 1) {
      final List<StyledChar> updated =
          List.from(editorState.widget.controller.styledChars);
      updated.removeAt(range.start);

      final newEnd = range.end - 1;
      for (int i = range.start; i < newEnd; i++) {
        if (i < updated.length) {
          updated[i] = StyledChar(
            char: updated[i].char,
            style: updated[i].style.copyWith(
                listType: 'normal',
                indent: 0,
                checked: false,
                strikethrough: false),
          );
        }
      }

      editorState.widget.controller.saveUndoState();
      editorState.widget.controller.styledChars = updated;
      editorState.widget.controller.currentActiveStyle =
          editorState.widget.controller.currentActiveStyle.copyWith(
        listType: 'normal',
        checked: false,
        strikethrough: false,
        indent: 0,
      );

      editorState.parseCurrentSegments();

      editorState.widget.controller.value = TextEditingValue(
        text: updated.map((sc) => sc.char).join(),
        selection: TextSelection.collapsed(offset: range.start),
      );

      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult handleTabKey({
    required int segmentIndex,
    required RangeTextEditingController controller,
    required NewSingleDocumentEditorState editorState,
    required bool outdent,
  }) {
    editorState.changeIndent(segmentIndex, outdent: outdent);
    return KeyEventResult.handled;
  }
}

class ParagraphBlockRegistry {
  static final List<ParagraphBlockBehavior> _behaviors = [
    ChecklistBehavior(),
    BulletBehavior(),
    NumberBehavior(),
    QuoteBehavior(),
  ];

  static void register(ParagraphBlockBehavior behavior) {
    _behaviors.add(behavior);
  }

  static ParagraphBlockBehavior? getBehaviorForText(String text) {
    for (final behavior in _behaviors) {
      if (behavior.hasPrefix(text)) {
        return behavior;
      }
    }
    return null;
  }

  static ParagraphBlockBehavior? getBehaviorForListType(String listType) {
    for (final behavior in _behaviors) {
      if (behavior.listType == listType) {
        return behavior;
      }
    }
    return null;
  }

  static bool hasAnyPrefix(String text) {
    return getBehaviorForText(text) != null;
  }
}

class ChecklistBehavior extends ParagraphBlockBehavior {
  @override
  String get listType => 'checkbox';

  @override
  bool hasPrefix(String text) {
    return text.isNotEmpty && (text[0] == '\u2610' || text[0] == '\u2611');
  }

  @override
  int get prefixLen => 1;

  @override
  StyledChar getPrefixChar(Style style) {
    return StyledChar(
      char: '\u2610',
      style: style.copyWith(checked: false, strikethrough: false),
    );
  }
}

class BulletBehavior extends ParagraphBlockBehavior {
  @override
  String get listType => 'bullet';

  @override
  bool hasPrefix(String text) {
    return text.isNotEmpty && text[0] == '•';
  }

  @override
  int get prefixLen => 1;

  @override
  StyledChar getPrefixChar(Style style) {
    return StyledChar(char: '•', style: style);
  }
}

class NumberBehavior extends ParagraphBlockBehavior {
  @override
  String get listType => 'number';

  @override
  bool hasPrefix(String text) {
    return text.isNotEmpty && text[0] == '\u2008';
  }

  @override
  int get prefixLen => 1;

  @override
  StyledChar getPrefixChar(Style style) {
    return StyledChar(char: '\u2008', style: style);
  }
}

class QuoteBehavior extends ParagraphBlockBehavior {
  @override
  String get listType => 'quote';

  @override
  bool hasPrefix(String text) {
    return text.isNotEmpty && text[0] == '›';
  }

  @override
  int get prefixLen => 1;

  @override
  StyledChar getPrefixChar(Style style) {
    return StyledChar(char: '›', style: style);
  }
}
