import 'dart:ui';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tactile_button.dart';
import 'rich_text_controller.dart';

class RichTextSelectionToolbar extends StatelessWidget {
  final EditableTextState editableTextState;

  const RichTextSelectionToolbar({
    super.key,
    required this.editableTextState,
  });

  @override
  Widget build(BuildContext context) {
    // Check which actions are enabled in the current editable text state
    final bool canSelectAll = editableTextState.selectAllEnabled;
    final bool canCopy = editableTextState.copyEnabled;
    final bool canCut = editableTextState.cutEnabled;
    final bool canPaste = editableTextState.pasteEnabled;

    final controller = editableTextState.widget.controller;
    final bool isRichText = controller is RichTextEditingController;
    final bool hasSelection = !editableTextState.textEditingValue.selection.isCollapsed;

    final List<Widget> items = [];

    if (canSelectAll) {
      items.add(_buildButton(
        label: "select all",
        onTap: () => editableTextState.selectAll(SelectionChangedCause.toolbar),
      ));
    }

    if (canCopy) {
      items.add(_buildButton(
        label: "copy",
        onTap: () {
          if (isRichText) {
            (controller as RichTextEditingController).copy();
            editableTextState.hideToolbar();
          } else {
            editableTextState.copySelection(SelectionChangedCause.toolbar);
          }
        },
      ));
    }

    if (canCut) {
      items.add(_buildButton(
        label: "cut",
        onTap: () {
          if (isRichText) {
            (controller as RichTextEditingController).cut();
            editableTextState.hideToolbar();
          } else {
            editableTextState.cutSelection(SelectionChangedCause.toolbar);
          }
        },
      ));
    }

    if (canPaste) {
      items.add(_buildButton(
        label: "paste",
        onTap: () {
          if (isRichText) {
            (controller as RichTextEditingController).paste();
            editableTextState.hideToolbar();
          } else {
            editableTextState.pasteText(SelectionChangedCause.toolbar);
          }
        },
      ));
    }

    if (isRichText && hasSelection) {
      items.add(_buildButton(
        label: "duplicate",
        onTap: () {
          (controller as RichTextEditingController).duplicateSelection();
          editableTextState.hideToolbar();
        },
      ));
    }

    if (isRichText && hasSelection) {
      items.add(_buildButton(
        label: "highlight",
        onTap: () {
          (controller as RichTextEditingController).toggleStyleAttribute(
            'highlight',
            value: const Color(0xFFFFCC00).withValues(alpha: 0.35),
          );
          editableTextState.hideToolbar();
        },
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Horizontal layout with vertical dividers
    final List<Widget> rowChildren = [];
    for (int i = 0; i < items.length; i++) {
      rowChildren.add(items[i]);
      if (i < items.length - 1) {
        rowChildren.add(
          Container(
            width: 0.6,
            height: 14,
            color: Colors.white.withOpacity(0.15),
          ),
        );
      }
    }

    final anchors = editableTextState.contextMenuAnchors;

    // Position using CustomSingleChildLayout with TextSelectionToolbarLayoutDelegate
    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      ),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF333333),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 10,
              spreadRadius: 0,
              color: Colors.black.withOpacity(0.15),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      useAppleSpring: true,
      compressionScale: 0.7, // Apple tactile compression scale: 0.7
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}
