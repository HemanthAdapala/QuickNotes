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
    const primaryTextColor = Color(0xFF333333);
    const backgroundColor = Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
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
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Markdown(
                  data: markdownContent,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
                      color: const Color(0xFF4A4A4A),
                      height: 1.6,
                    ),
                    listBullet: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF4A4A4A),
                      height: 1.6,
                    ),
                    blockquote: GoogleFonts.inter(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF8C8987),
                    ),
                    blockquoteDecoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFD9D9D9), width: 4),
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
