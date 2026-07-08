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
        icon: Icons.select_all_rounded,
        label: "select all",
        onTap: () => editableTextState.selectAll(SelectionChangedCause.toolbar),
      ));
    }

    if (canCopy) {
      items.add(_buildButton(
        icon: Icons.content_copy_rounded,
        label: "copy",
        onTap: () => editableTextState.copySelection(SelectionChangedCause.toolbar),
      ));
    }

    if (canCut) {
      items.add(_buildButton(
        icon: Icons.content_cut_rounded,
        label: "cut",
        onTap: () => editableTextState.cutSelection(SelectionChangedCause.toolbar),
      ));
    }

    if (canPaste) {
      items.add(_buildButton(
        icon: Icons.content_paste_rounded,
        label: "paste",
        onTap: () => editableTextState.pasteText(SelectionChangedCause.toolbar),
      ));
    }

    // Optional highlight option for rich-text note blocks
    if (isRichText && hasSelection) {
      items.add(_buildButton(
        icon: Icons.border_color_rounded,
        label: "highlight",
        onTap: () {
          (controller as RichTextEditingController).toggleStyleAttribute(
            'highlight',
            value: const Color(0xFFFFCC00).withValues(alpha: 0.35),
          );
        },
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Horizontal layout without dividers to align perfectly with SVG guidelines
    final List<Widget> rowChildren = [];
    for (int i = 0; i < items.length; i++) {
      rowChildren.add(items[i]);
      if (i < items.length - 1) {
        rowChildren.add(const SizedBox(width: 8)); // Spacious horizontal gap
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19.5),
          boxShadow: [
            // Outer S0 high-visibility shadow stack
            BoxShadow(
              offset: const Offset(1.25, 0),
              blurRadius: 0,
              spreadRadius: -0.75,
              color: const Color(0xFFD0D0D0),
            ),
            BoxShadow(
              offset: const Offset(-1.25, 0),
              blurRadius: 0,
              spreadRadius: -0.75,
              color: const Color(0xFFD0D0D0),
            ),
            BoxShadow(
              offset: const Offset(0, 0),
              blurRadius: 0,
              spreadRadius: 0.5,
              color: const Color(0xFFCCCCCC),
            ),
            BoxShadow(
              offset: const Offset(0, 8),
              blurRadius: 15,
              spreadRadius: 0,
              color: Colors.black.withValues(alpha: 0.02),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(
              height: 39,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19.5),
                color: const Color(0xFF333333).withValues(alpha: 0.92),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 0.8,
                ),
                boxShadow: [
                  // Inner Liquid Glass shadow stack
                  BoxShadow(
                    offset: const Offset(0, 1.25),
                    blurRadius: 0.25,
                    spreadRadius: 0,
                    color: const Color(0xFF282828),
                    inset: true,
                  ),
                  BoxShadow(
                    offset: const Offset(0, -1.25),
                    blurRadius: 0.25,
                    spreadRadius: 0,
                    color: const Color(0xFF282828),
                    inset: true,
                  ),
                  BoxShadow(
                    offset: const Offset(0, 40),
                    blurRadius: 10,
                    spreadRadius: -40,
                    color: const Color(0xFF282828),
                    inset: true,
                  ),
                  BoxShadow(
                    offset: const Offset(0, -40),
                    blurRadius: 10,
                    spreadRadius: -40,
                    color: const Color(0xFF282828),
                    inset: true,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TactileButton(
      useAppleSpring: true,
      compressionScale: 0.7, // Apple tactile compression scale: 0.7
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
