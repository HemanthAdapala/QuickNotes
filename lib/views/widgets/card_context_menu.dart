import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/quick_notes_haptics.dart';

/// Three-dot overflow menu button for Note and Task cards.
class CardOverflowButton extends StatefulWidget {
  final VoidCallback onTap;

  const CardOverflowButton({
    super.key,
    required this.onTap,
  });

  @override
  State<CardOverflowButton> createState() => _CardOverflowButtonState();
}

class _CardOverflowButtonState extends State<CardOverflowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    QuickNotesHaptics.buttonPress();
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Card menu',
      child: GestureDetector(
        key: const ValueKey('card_overflow_menu_button'),
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 30.0,
            height: 30.0,
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF5A5A5A) : const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3F000000),
                  blurRadius: 16.0,
                  offset: Offset(0, 0),
                  spreadRadius: 0.0,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.more_vert,
                size: 20.0,
                color: isDark ? Colors.white : const Color(0xFF333333),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive anchor-based More Options component for Note and Task cards.
///
/// Anchors the three-dot overflow button and contextual popup menu relative
/// to the card's white content strip using Flutter's relationship-based layout
/// ([Align] and [Padding]), deriving bounds directly from parent constraints
/// without hardcoded coordinates.
class CardMoreOptionsMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onAddToHomeScreen;
  final VoidCallback onDelete;
  final EdgeInsets padding;

  const CardMoreOptionsMenu({
    super.key,
    required this.isOpen,
    required this.onOpen,
    required this.onClose,
    required this.onAddToHomeScreen,
    required this.onDelete,
    this.padding = const EdgeInsets.only(top: 21.0, right: 19.0),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: padding,
        child: isOpen
            ? TapRegion(
                onTapOutside: (_) => onClose(),
                child: CardContextMenu(
                  onAddToHomeScreen: () {
                    onClose();
                    onAddToHomeScreen();
                  },
                  onDelete: () {
                    onClose();
                    onDelete();
                  },
                ),
              )
            : CardOverflowButton(
                onTap: onOpen,
              ),
      ),
    );
  }
}

/// Compact contextual popup menu for Note and Task cards.
class CardContextMenu extends StatefulWidget {
  final VoidCallback onAddToHomeScreen;
  final VoidCallback onDelete;

  const CardContextMenu({
    super.key,
    required this.onAddToHomeScreen,
    required this.onDelete,
  });

  @override
  State<CardContextMenu> createState() => _CardContextMenuState();
}

class _CardContextMenuState extends State<CardContextMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 30.0 / 186.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildItem({
    required Key key,
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF333333);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          QuickNotesHaptics.selection();
          onTap();
        },
        child: Container(
          height: 40.0,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          alignment: Alignment.centerLeft,
          color: Colors.transparent,
          child: Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 16.0,
                height: 16.0,
                colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0x26FFFFFF)
        : const Color(0x14000000);

    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.topRight,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          key: const ValueKey('card_context_menu'),
          width: 186.0,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0x14000000),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x4D000000)
                    : const Color(0x26000000),
                blurRadius: 16.0,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildItem(
                key: const ValueKey('menu_item_add_to_home_screen'),
                iconAsset: 'assets/New Icons/mobile-notch.svg',
                label: 'Add to HomeScreen',
                onTap: widget.onAddToHomeScreen,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Container(
                  height: 0.6,
                  color: dividerColor,
                ),
              ),
              _buildItem(
                key: const ValueKey('menu_item_delete'),
                iconAsset: 'assets/New Icons/trash.svg',
                label: 'Delete',
                onTap: widget.onDelete,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
