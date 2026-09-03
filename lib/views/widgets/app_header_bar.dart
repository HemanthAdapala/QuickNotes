import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/motion_constants.dart';
import 'app_bottom_navigation_bar.dart'; // Import BottomBarGlassSurface
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
        _isInteractivityReady = disableAnimations;
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
    final Duration effectiveExpandDuration =
        disableAnimations ? Duration.zero : widget.expandDuration;
    final Duration effectiveShrinkDuration =
        disableAnimations ? Duration.zero : widget.shrinkDuration;
    final Duration effectiveFadeDuration = disableAnimations
        ? Duration.zero
        : (widget.isExpanded
            ? QuickNotesMotion.kMotionMicro
            : QuickNotesMotion.kMotionRelease);
    final Duration effectivePopupDuration = disableAnimations
        ? Duration.zero
        : (widget.isExpanded
            ? QuickNotesMotion.kMotionPage
            : QuickNotesMotion.kMotionPageReverse);

    final double effectiveRightWidth =
        widget.isExpanded ? widget.expandedWidth : widget.rightWidth;

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
      leftButton = BottomBarGlassSurface(
        width: widget.leftWidth,
        height: 44.0,
        borderRadius: BorderRadius.circular(22.0),
        child: TactileButton(
          onTap: widget.onLeftTap ?? () {},
          child: Center(child: widget.leftChild),
        ),
      );
      if (widget.leftHeroTag.isNotEmpty) {
        leftButton = Hero(
          tag: widget.leftHeroTag,
          child: leftButton,
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
          if (widget.titleWidget != null)
            Positioned(
              left: widget.leftWidth,
              right: effectiveRightWidth,
              top: 0,
              bottom: 0,
              child: Center(child: widget.titleWidget!),
            )
          else if (widget.title != null)
            Positioned(
              left: widget.leftWidth,
              right: effectiveRightWidth,
              top: 0,
              bottom: 0,
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

          // Right Button/Pill (Glass Surface with configurable in-place expansion/shrinking)
          if (widget.rightChild != null)
            Positioned(
              right: 0,
              top: 0,
              child: AnimatedContainer(
                duration: widget.isExpanded
                    ? effectiveExpandDuration
                    : effectiveShrinkDuration,
                curve: widget.isExpanded
                    ? widget.expandCurve
                    : widget.shrinkCurve,
                width: widget.isExpanded
                    ? widget.expandedWidth
                    : widget.rightWidth,
                height: widget.isExpanded ? widget.expandedHeight : 44.0,
                onEnd: _handleAnimationEnd,
                child: Hero(
                  tag: widget.rightHeroTag,
                  child: BottomBarGlassSurface(
                    width: widget.isExpanded
                        ? widget.expandedWidth
                        : widget.rightWidth,
                    height: widget.isExpanded ? widget.expandedHeight : 44.0,
                    borderRadius: BorderRadius.circular(
                        widget.isExpanded ? 20.0 : 22.0),
                    useFrost: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          widget.isExpanded ? 20.0 : 22.0),
                      child: Stack(
                        children: [
                          // Collapsed state: 3-dots icon
                          AnimatedOpacity(
                            duration: effectiveFadeDuration,
                            curve: QuickNotesMotion.kMotionAppleEase,
                            opacity: widget.isExpanded ? 0.0 : 1.0,
                            child: IgnorePointer(
                              ignoring: widget.isExpanded,
                              child: widget.rightChild!,
                            ),
                          ),

                          // Expanded state: MoreOptionsPopup menu items (staggered fade & subtle slide)
                          // DEF-07 fix: IgnorePointer gates hit-testing during expansion animation
                          if (widget.expandedChild != null)
                            AnimatedOpacity(
                              duration: effectivePopupDuration,
                              curve: QuickNotesMotion.kMotionAppleEase,
                              opacity: widget.isExpanded ? 1.0 : 0.0,
                              child: IgnorePointer(
                                ignoring: !isContentInteractive,
                                child: AnimatedSlide(
                                  duration: effectivePopupDuration,
                                  curve: QuickNotesMotion.kMotionAppleEase,
                                  offset: widget.isExpanded
                                      ? Offset.zero
                                      : const Offset(0, 0.08),
                                  child: OverflowBox(
                                    minWidth: widget.expandedWidth,
                                    maxWidth: widget.expandedWidth,
                                    minHeight: widget.expandedHeight,
                                    maxHeight: widget.expandedHeight,
                                    alignment: Alignment.topRight,
                                    child: FocusScope(
                                      node: _menuFocusScopeNode,
                                      autofocus: isContentInteractive,
                                      canRequestFocus: isContentInteractive,
                                      child: widget.expandedChild!,
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
