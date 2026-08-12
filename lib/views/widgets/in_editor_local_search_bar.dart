import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/in_editor_local_search_controller.dart';
import 'app_bottom_navigation_bar.dart';
import 'tactile_button.dart';

/// Standalone, modular search bar for NoteEditorScreen.
/// Encapsulates text controller, focus node, glass UI, and match navigation.
class InEditorLocalSearchBar extends StatefulWidget {
  final InEditorLocalSearchController searchController;
  final String titleText;
  final String bodyText;
  final ValueChanged<LocalSearchMatch?> onMatchChanged;
  final VoidCallback onClose;

  const InEditorLocalSearchBar({
    super.key,
    required this.searchController,
    required this.titleText,
    required this.bodyText,
    required this.onMatchChanged,
    required this.onClose,
  });

  @override
  State<InEditorLocalSearchBar> createState() => _InEditorLocalSearchBarState();
}

class _InEditorLocalSearchBarState extends State<InEditorLocalSearchBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchStateChanged);
  }

  @override
  void didUpdateWidget(covariant InEditorLocalSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onSearchStateChanged);
      widget.searchController.addListener(_onSearchStateChanged);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchStateChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchStateChanged() {
    if (mounted) {
      widget.onMatchChanged(widget.searchController.currentMatch);
    }
  }

  void _handleTextChange(String val) {
    widget.searchController.performSearch(val, widget.titleText, widget.bodyText);
    widget.onMatchChanged(widget.searchController.currentMatch);
  }

  void _handleClose() {
    HapticFeedback.selectionClick();
    _textCtrl.clear();
    widget.searchController.clear();
    widget.onMatchChanged(null);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.0,
      child: Row(
        children: [
          // Left glass close button (44x44)
          BottomBarGlassSurface(
            width: 44.0,
            height: 44.0,
            borderRadius: BorderRadius.circular(22.0),
            useFrost: true,
            child: TactileButton(
              useAppleSpring: true,
              compressionScale: 0.7,
              settleDuration: const Duration(milliseconds: 1000),
              onTap: _handleClose,
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Color(0xFF1C1C1E),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Center expanded glass search field
          Expanded(
            child: BottomBarGlassSurface(
              width: double.infinity,
              height: 44.0,
              borderRadius: BorderRadius.circular(22.0),
              useFrost: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFD49200),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Find in note...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onChanged: _handleTextChange,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: widget.searchController,
                      builder: (context, _) {
                        final total = widget.searchController.totalMatches;
                        final current = widget.searchController.currentMatchIndex;
                        if (_textCtrl.text.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x1A787880),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            total > 0 ? "${current + 1}/$total" : "0",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF555558),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Right glass match navigation pill (88x44)
          ListenableBuilder(
            listenable: widget.searchController,
            builder: (context, _) {
              final hasMatches = widget.searchController.totalMatches > 0;

              return BottomBarGlassSurface(
                width: 88.0,
                height: 44.0,
                borderRadius: BorderRadius.circular(22.0),
                useFrost: true,
                child: Row(
                  children: [
                    Expanded(
                      child: TactileButton(
                        useAppleSpring: true,
                        compressionScale: 0.7,
                        settleDuration: const Duration(milliseconds: 1000),
                        onTap: hasMatches
                            ? () {
                                HapticFeedback.selectionClick();
                                widget.searchController.previousMatch();
                              }
                            : () {},
                        child: const Center(
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFF1C1C1E),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 20, color: const Color(0x33000000)),
                    Expanded(
                      child: TactileButton(
                        useAppleSpring: true,
                        compressionScale: 0.7,
                        settleDuration: const Duration(milliseconds: 1000),
                        onTap: hasMatches
                            ? () {
                                HapticFeedback.selectionClick();
                                widget.searchController.nextMatch();
                              }
                            : () {},
                        child: const Center(
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF1C1C1E),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
