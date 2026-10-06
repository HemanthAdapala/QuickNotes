import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/motion_constants.dart';
import '../../core/motion/quick_notes_visual_preset.dart';
import 'app_bottom_navigation_bar.dart'; // Import BottomBarGlassSurface
import 'liquid_glass_morph_container.dart';
import 'quick_notes_glass_action_morph.dart';
import 'quick_notes_visual_transition.dart';
import 'tactile_button.dart';

class AppHeaderBar extends StatefulWidget {
  final Widget? leftChild;
  final VoidCallback? onLeftTap;
  final double leftWidth;
  final String leftHeroTag;

  final Widget? rightChild;
  final double rightWidth;
  final String rightHeroTag;

  final String? title;
  final Widget? titleWidget;
  final Color? titleColor;

  final bool isExpanded;
  final double expandedWidth;
  final double expandedHeight;
  final Widget? expandedChild;
  final VoidCallback? onCollapse;
  final Duration expandDuration;
  final Duration shrinkDuration;
  final Curve expandCurve;
  final Curve shrinkCurve;

  /// Optional visual motion preset. When provided, [QuickNotesVisualTransition.liquidGlass]
  /// is used as the sole authoritative visual transition engine instead of legacy containers.
  final QuickNotesVisualPreset? visualPreset;

  /// When true, [leftChild] is treated as a self-contained interactive control
  /// (such as [QuickNotesLiquidGlassBackButton]) and mounted directly within its
  /// [Hero] wrapper without being wrapped in the legacy [BottomBarGlassSurface]
  /// and [TactileButton].
  ///
  /// Defaults to false to strictly preserve legacy behavior for existing callers.
  final bool useSelfContainedLeftControl;

  const AppHeaderBar({
    super.key,
    this.leftChild,
    this.onLeftTap,
    this.leftWidth = 44.0,
    this.leftHeroTag = 'hero_header_leading',
    this.rightChild,
    this.rightWidth = 44.0,
    this.rightHeroTag = 'hero_header_trailing',
    this.title,
    this.titleWidget,
    this.titleColor,
    this.isExpanded = false,
    this.expandedWidth = 192.0,
    this.expandedHeight = 100.0,
    this.expandedChild,
    this.onCollapse,
    this.expandDuration = QuickNotesMotion.kMotionPage,
    this.shrinkDuration = QuickNotesMotion.kMotionPageReverse,
    this.expandCurve = QuickNotesMotion.kMotionAppleEase,
    this.shrinkCurve = QuickNotesMotion.kMotionAppleEase,
    this.visualPreset,
    this.useSelfContainedLeftControl = false,
  });

  @override
  State<AppHeaderBar> createState() => _AppHeaderBarState();
}

class _AppHeaderBarState extends State<AppHeaderBar> {
  late bool _isInteractivityReady;
  final FocusScopeNode _menuFocusScopeNode = FocusScopeNode(
    debugLabel: 'AppHeaderBar_MenuFocusScope',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void dispose() {
    _menuFocusScopeNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isInteractivityReady = widget.isExpanded;
    if (widget.isExpanded) {
      _focusExpandedMenu();
    }
  }

  void _focusExpandedMenu() {
    if (!mounted || !widget.isExpanded || !_isInteractivityReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isExpanded && _isInteractivityReady) {
        final FocusNode? currentFocused = _menuFocusScopeNode.focusedChild;
        final bool childHasFocus = currentFocused != null &&
            currentFocused != _menuFocusScopeNode &&
            currentFocused.canRequestFocus;
        if (!childHasFocus) {
          final FocusNode? firstChild =
              _menuFocusScopeNode.traversalDescendants.firstOrNull;
          if (firstChild != null) {
            firstChild.requestFocus();
          } else {
            _menuFocusScopeNode.requestFocus();
          }
        }
      }
    });
  }

  @override
  void didUpdateWidget(AppHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (!widget.isExpanded) {
        _isInteractivityReady = false;
        _menuFocusScopeNode.unfocus();
      } else {
        final bool disableAnimations = MediaQuery.of(context).disableAnimations;
        _isInteractivityReady = disableAnimations ||
            widget.expandedChild is QuickNotesGlassActionMorph;
      }
    }
  }

  void _handleAnimationEnd() {
    if (mounted && widget.isExpanded && !_isInteractivityReady) {
      setState(() {
        _isInteractivityReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    // Gated interactivity: expanded child only accepts pointer events once fully settled
    final bool isContentInteractive =
        widget.isExpanded && (disableAnimations || _isInteractivityReady);

    _menuFocusScopeNode.canRequestFocus = isContentInteractive;
    _menuFocusScopeNode.descendantsAreFocusable = isContentInteractive;

    final FocusNode? currentFocused = _menuFocusScopeNode.focusedChild;
    final bool childHasFocus = currentFocused != null &&
        currentFocused != _menuFocusScopeNode &&
        currentFocused.canRequestFocus;

    if (isContentInteractive && !childHasFocus) {
      _focusExpandedMenu();
    }

    Widget? leftButton;
    if (widget.leftChild != null) {
      if (widget.useSelfContainedLeftControl) {
        leftButton = widget.leftChild;
      } else {
        leftButton = BottomBarGlassSurface(
          width: widget.leftWidth,
          height: 44.0,
          borderRadius: BorderRadius.circular(22.0),
          child: TactileButton(
            onTap: widget.onLeftTap ?? () {},
            child: Center(child: widget.leftChild),
          ),
        );
      }
      if (widget.leftHeroTag.isNotEmpty) {
        leftButton = Hero(
          tag: widget.leftHeroTag,
          child: leftButton!,
        );
      }
    }

    final body = SizedBox(
      height: widget.isExpanded ? widget.expandedHeight : 44.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left Button (Glass Surface)
          if (leftButton != null)
            Positioned(
              left: 0,
              top: 0,
              width: widget.leftWidth,
              height: 44.0,
              child: leftButton,
            ),

          // Center Title Slot — titleWidget takes precedence.
          // Isolated from popup expansion geometry (frozen at top: 0, height: 44.0, right: widget.rightWidth).
          if (widget.titleWidget != null)
            Positioned(
              left: widget.leftWidth,
              right: widget.rightWidth,
              top: 0,
              height: 44.0,
              child: Center(child: widget.titleWidget!),
            )
          else if (widget.title != null)
            Positioned(
              left: widget.leftWidth,
              right: widget.rightWidth,
              top: 0,
              height: 44.0,
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    widget.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.43,
                      color: widget.titleColor ?? const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
            ),

          // Right Button/Pill (QuickNotesVisualTransition when visualPreset provided, else LiquidGlassMorphContainer)
          if (widget.rightChild != null)
            Positioned(
              right: 0,
              top: 0,
              child: widget.expandedChild != null
                  ? (widget.expandedChild is QuickNotesGlassActionMorph
                      ? FocusScope(
                          node: _menuFocusScopeNode,
                          autofocus: isContentInteractive,
                          canRequestFocus: isContentInteractive,
                          child: widget.expandedChild!,
                        )
                      : (widget.visualPreset != null
                          ? QuickNotesVisualTransition.liquidGlass(
                          key: const ValueKey('app_header_bar_visual_transition'),
                          state: widget.isExpanded,
                          preset: widget.visualPreset!,
                          collapsedSize: Size(widget.rightWidth, 44.0),
                          expandedSize:
                              Size(widget.expandedWidth, widget.expandedHeight),
                          collapsedBorderRadius: BorderRadius.circular(22.0),
                          expandedBorderRadius: BorderRadius.circular(20.0),
                          anchor: Alignment.topRight,
                          useFrost: true,
                          heroTag: widget.rightHeroTag.isNotEmpty
                              ? widget.rightHeroTag
                              : null,
                          onTransitionEnd: _handleAnimationEnd,
                          collapsedChild: widget.rightChild!,
                          expandedChild: FocusScope(
                            node: _menuFocusScopeNode,
                            autofocus: isContentInteractive,
                            canRequestFocus: isContentInteractive,
                            child: widget.expandedChild!,
                          ),
                        )
                      : LiquidGlassMorphContainer(
                          isExpanded: widget.isExpanded,
                          collapsedSize: Size(widget.rightWidth, 44.0),
                          expandedSize:
                              Size(widget.expandedWidth, widget.expandedHeight),
                          collapsedBorderRadius: BorderRadius.circular(22.0),
                          expandedBorderRadius: BorderRadius.circular(20.0),
                          anchor: Alignment.topRight,
                          useFrost: true,
                          heroTag: widget.rightHeroTag.isNotEmpty
                              ? widget.rightHeroTag
                              : null,
                          onTransitionEnd: _handleAnimationEnd,
                          collapsedChild: widget.rightChild!,
                          expandedChild: FocusScope(
                            node: _menuFocusScopeNode,
                            autofocus: isContentInteractive,
                            canRequestFocus: isContentInteractive,
                            child: widget.expandedChild!,
                          ),
                        )))
                  : Hero(
                      tag: widget.rightHeroTag,
                      child: BottomBarGlassSurface(
                        width: widget.rightWidth,
                        height: 44.0,
                        borderRadius: BorderRadius.circular(22.0),
                        useFrost: true,
                        child: widget.rightChild!,
                      ),
                    ),
            ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.isExpanded) {
            widget.onCollapse?.call();
          }
        },
      },
      child: body,
    );
  }
}
