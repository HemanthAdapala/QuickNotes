import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/motion/quick_notes_haptics.dart';

class MoreOptionsPopup extends StatelessWidget {
  final VoidCallback? onDeleteData;
  final VoidCallback? onRefresh;
  final Color? deleteColor;
  final Color? refreshColor;
  final Color? dividerColor;

  const MoreOptionsPopup({
    super.key,
    this.onDeleteData,
    this.onRefresh,
    this.deleteColor,
    this.refreshColor,
    this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDeleteColor = deleteColor ?? const Color(0xFF333333);
    final effectiveRefreshColor = refreshColor ?? const Color(0xFF333333);
    final effectiveDividerColor = dividerColor ?? const Color(0x33000000);

    return SizedBox(
      width: 192,
      height: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delete Data Option
          Semantics(
            button: true,
            child: FocusableActionDetector(
              includeFocusSemantics: false,
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (intent) {
                    QuickNotesHaptics.buttonPress();
                    onDeleteData?.call();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                onTap: () {
                  QuickNotesHaptics.buttonPress();
                  onDeleteData?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 192,
                  height: 50,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: 192,
                          height: 50,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side:
                                  BorderSide(width: 0.20, color: effectiveDividerColor),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 17,
                        child: SvgPicture.asset(
                          'assets/icons/trash.svg',
                          width: 16,
                          height: 16,
                          colorFilter:
                              ColorFilter.mode(effectiveDeleteColor, BlendMode.srcIn),
                        ),
                      ),
                      Positioned(
                        left: 39,
                        top: 10,
                        child: SizedBox(
                          width: 122,
                          height: 30,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Delete Data',
                              style: GoogleFonts.inter(
                                color: effectiveDeleteColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
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

          // Refresh Option
          Semantics(
            button: true,
            child: FocusableActionDetector(
              includeFocusSemantics: false,
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (intent) {
                    QuickNotesHaptics.buttonPress();
                    onRefresh?.call();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                onTap: () {
                  QuickNotesHaptics.buttonPress();
                  onRefresh?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 192,
                  height: 50,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 14,
                        top: 17,
                        child: SvgPicture.asset(
                          'assets/icons/refresh.svg',
                          width: 16,
                          height: 16,
                          colorFilter:
                              ColorFilter.mode(effectiveRefreshColor, BlendMode.srcIn),
                        ),
                      ),
                      Positioned(
                        left: 39,
                        top: 10,
                        child: SizedBox(
                          width: 122,
                          height: 30,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Refresh',
                              style: GoogleFonts.inter(
                                color: effectiveRefreshColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
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
        ],
      ),
    );
  }
}
