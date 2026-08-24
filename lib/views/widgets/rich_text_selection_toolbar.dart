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
    final bool hasSelection =
        !editableTextState.textEditingValue.selection.isCollapsed;

    final List<Widget> items = [];

    if (canSelectAll) {
      items.add(_buildButton(
        label: "Select All",
        onTap: () => editableTextState.selectAll(SelectionChangedCause.toolbar),
      ));
    }

    if (canCopy) {
      items.add(_buildButton(
        label: "Copy",
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
        label: "Cut",
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
        label: "Paste",
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
        label: "Duplicate",
        onTap: () {
          (controller as RichTextEditingController).duplicateSelection();
          editableTextState.hideToolbar();
        },
      ));
    }

    if (isRichText && hasSelection) {
      items.add(_buildButton(
        label: "Highlight",
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
            height: 16,
            color: Colors.white.withValues(alpha: 0.2),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xEC222226),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                  spreadRadius: 0,
                  color: Color(0xFF333333).withValues(alpha: 0.25),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: rowChildren,
            ),
          ),
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
      compressionScale: 0.8,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
