// ──────────────────────────────────────────────────────────────────────────────
// folder_card.dart — Reusable 3D Folder Card & Painters
//
// Shared by FolderManagementScreen and SearchScreen.
// Features:
//   - 3D folder shape with FolderBgPainter and FolderFgPainter.
//   - Peeking decorative notepad cards.
//   - Sticker overlay / customize action button.
//   - Folder title with query match text highlighting (for search).
//   - Note count badge.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/folder.dart';
import '../widgets/tactile_button.dart';

class FolderGridCard extends StatelessWidget {
  final Folder folder;
  final int index;
  final int noteCount;
  final String query;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final VoidCallback? onCustomizeTap;

  const FolderGridCard({
    super.key,
    required this.folder,
    required this.index,
    required this.noteCount,
    this.query = '',
    required this.onTap,
    this.onLongPressStart,
    this.onCustomizeTap,
  });

  Color _darken(Color color, [double amount = .08]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color bgColorDark;
    if (folder.colorHex != null) {
      final parsed = Color(int.parse(folder.colorHex!));
      bgColor = parsed;
      bgColorDark = _darken(parsed);
    } else {
      bgColor = const Color(0xFFB0B0A8);
      bgColorDark = const Color(0xFF9E9E96);
    }

    final customizeTap = onCustomizeTap;
    final baseTitleStyle = GoogleFonts.inter(
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF1C1C1E),
    );
    final highlightTitleStyle = baseTitleStyle.copyWith(
      color: const Color(0xFFD49200),
      fontWeight: FontWeight.w700,
    );

    return TactileButton(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      compressionScale: 0.95,
      useAppleSpring: true,
      playSelectionHaptic: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 150.0,
                height: 154.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 20.916,
                      left: 0,
                      width: 150.0,
                      height: 133.0,
                      child: CustomPaint(
                        painter: FolderBgPainter(color: bgColorDark),
                      ),
                    ),

                    Positioned(
                      left: 13.9,
                      top: 9.5,
                      child: Transform.rotate(
                        angle: -10.0 * pi / 180.0,
                        alignment: Alignment.topLeft,
                        child: const DecorativeNoteCard(),
                      ),
                    ),

                    Positioned(
                      left: 73.5,
                      top: -1.5,
                      child: Transform.rotate(
                        angle: 10.0 * pi / 180.0,
                        alignment: Alignment.topLeft,
                        child: const DecorativeNoteCard(),
                      ),
                    ),

                    Positioned(
                      top: 20.916,
                      left: 0,
                      width: 150.0,
                      height: 133.0,
                      child: CustomPaint(
                        painter: FolderFgPainter(color: bgColor),
                      ),
                    ),

                    Positioned(
                      right: 8.0,
                      bottom: 8.0,
                      width: 36.0,
                      height: 36.0,
                      child: folder.sticker != null
                          ? Image.asset(
                              "assets/stickers/${folder.sticker}",
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            )
                          : (customizeTap != null
                              ? TactileButton(
                                  onTap: customizeTap,
                                  compressionScale: 0.8,
                                  useAppleSpring: true,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4.0,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Color(0xFF8E8E93),
                                      size: 20,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: RichText(
                  text: TextSpan(
                    children: _buildHighlightSpans(
                      folder.name,
                      query,
                      base: baseTitleStyle,
                      highlight: highlightTitleStyle,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: const Color(0x1A787880),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  "$noteCount",
                  style: GoogleFonts.inter(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF555558),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightSpans(
    String text,
    String query, {
    required TextStyle base,
    required TextStyle highlight,
  }) {
    if (query.isEmpty) return [TextSpan(text: text, style: base)];

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    int start = 0;

    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: base));
      }
      spans.add(TextSpan(
          text: text.substring(idx, idx + query.length), style: highlight));
      start = idx + query.length;
    }
    return spans;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative peeking notepad
// ─────────────────────────────────────────────────────────────────────────────
class DecorativeNoteCard extends StatelessWidget {
  const DecorativeNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.0,
      height: 86.0,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: 64.0,
            height: 86.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16.0,
                    offset: Offset.zero,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: 64.0,
            height: 41.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          Positioned(
            top: 11.0,
            left: 0,
            width: 64.0,
            height: 75.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6.0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5,
                    (i) => Container(
                      height: 1.5,
                      margin: EdgeInsets.only(right: i == 4 ? 14.0 : 0.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E2DF),
                        borderRadius: BorderRadius.circular(1.0),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Folder Background Painter
// ─────────────────────────────────────────────────────────────────────────────
class FolderBgPainter extends CustomPainter {
  final Color color;

  const FolderBgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20.0),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawRRect(rrect, shadowPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant FolderBgPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Folder Foreground Flap Painter
// ─────────────────────────────────────────────────────────────────────────────
class FolderFgPainter extends CustomPainter {
  final Color color;

  const FolderFgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 150.0;
    final double sy = size.height / 133.0;

    Path svgPath() {
      final p = Path();
      p.moveTo(0, 20.0007);
      p.cubicTo(0, 8.95454, 8.94541, 0, 19.9916, 0);
      p.cubicTo(34.3373, 0, 53.6809, 0, 68.5554, 0);
      p.cubicTo(72.7535, 0, 77.0289, 1.23472, 79.298, 4.7667);
      p.cubicTo(81.9393, 8.87798, 83.7342, 14.0167, 86.4703, 18.0011);
      p.cubicTo(88.7081, 21.2597, 92.7727, 22.3273, 96.7258, 22.3273);
      p.cubicTo(108.31, 22.3273, 120.325, 22.3273, 130.007, 22.3273);
      p.cubicTo(141.052, 22.3273, 150, 31.2816, 150, 42.3273);
      p.lineTo(150, 112.999);
      p.cubicTo(150, 124.045, 141.046, 133, 130, 133);
      p.lineTo(19.9916, 133);
      p.cubicTo(8.94541, 133, 0, 124.045, 0, 112.999);
      p.close();
      return p;
    }

    final path = svgPath().transform(
      Matrix4.diagonal3Values(sx, sy, 1.0).storage,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawPath(path.shift(const Offset(0, -2.0)), shadowPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant FolderFgPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
