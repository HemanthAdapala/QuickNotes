import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/editor_auto_scroll_controller.dart';
import 'app_bottom_navigation_bar.dart';
import 'tactile_button.dart';

/// Standalone, self-contained liquid glass quick-scroll pill widget for NoteEditorScreen.
/// Renders AutoScroll to Beginning (Up) and AutoScroll to End (Down) buttons.
/// Automatically handles fade-in/fade-out based on scrolling activity.
class EditorQuickScrollPill extends StatelessWidget {
  final EditorAutoScrollController controller;

  const EditorQuickScrollPill({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isVisible = controller.isVisible;
        final canTop = controller.canScrollToTop;
        final canBottom = controller.canScrollToBottom;

        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            opacity: isVisible ? 1.0 : 0.0,
            child: BottomBarGlassSurface(
              width: 44.0,
              height: 88.0,
              borderRadius: BorderRadius.circular(22.0),
              useFrost: true,
              child: Column(
                children: [
                  // Scroll to Beginning Button
                  Expanded(
                    child: TactileButton(
                      useAppleSpring: true,
                      compressionScale: 0.7,
                      settleDuration: const Duration(milliseconds: 1000),
                      onTap: canTop
                          ? () {
                              HapticFeedback.selectionClick();
                              controller.scrollToBeginning();
                            }
                          : () {},
                      child: Center(
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 24,
                          color: canTop
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFF1C1C1E).withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),

                  // Divider hairline
                  Container(
                    width: 20.0,
                    height: 0.8,
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.12),
                  ),

                  // Scroll to End Button
                  Expanded(
                    child: TactileButton(
                      useAppleSpring: true,
                      compressionScale: 0.7,
                      settleDuration: const Duration(milliseconds: 1000),
                      onTap: canBottom
                          ? () {
                              HapticFeedback.selectionClick();
                              controller.scrollToEnd();
                            }
                          : () {},
                      child: Center(
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 24,
                          color: canBottom
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFF1C1C1E).withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
