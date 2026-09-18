import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/app_header_bar.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String markdownContent;

  const LegalDocumentScreen({
    Key? key,
    required this.title,
    required this.markdownContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
    final bodyTextColor = isDark ? const Color(0xFFE5E5EA) : const Color(0xFF4A4A4A);
    final blockquoteTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8C8987);
    final blockquoteBorderColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD9D9D9);
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F7);
    final sheetColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_legal_back_${title.replaceAll(' ', '_')}',
                rightHeroTag: 'hero_legal_empty_${title.replaceAll(' ', '_')}',
                leftWidth: 44.0,
                rightWidth: 44.0,
                rightChild: null,
                onLeftTap: () {
                  Navigator.pop(context);
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                ),
                titleWidget: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            
            // Content Area (White Rounded Sheet)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFF2C2C2E),
                          width: 1.0,
                        )
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                   alignment: Alignment.topCenter,
                   child: ConstrainedBox(
                     constraints: const BoxConstraints(maxWidth: 402.0),
                     child: Markdown(
                  data: markdownContent,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 32.0 + MediaQuery.paddingOf(context).bottom),
                  styleSheet: MarkdownStyleSheet(
                    h1: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                    h2: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.4,
                    ),
                    h3: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                    p: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: bodyTextColor,
                      height: 1.6,
                    ),
                    listBullet: GoogleFonts.inter(
                      fontSize: 15,
                      color: bodyTextColor,
                      height: 1.6,
                    ),
                    blockquote: GoogleFonts.inter(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: blockquoteTextColor,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: blockquoteBorderColor, width: 4),
                      ),
                    ),
                  ),
                ),
                   ),
                 ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
