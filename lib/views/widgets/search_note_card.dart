// ──────────────────────────────────────────────────────────────────────────────
// search_note_card.dart — Search Note Result Card Widget
//
// DESIGN SPECIFICATION (Figma "Global Search Screen Notes"):
//   - Dual-layer stack with peeking top accent rim: Yellow Accent backing container
//     (Color(0xFFFFCC00), 20px radius) with white front card (Colors.white, 20px radius)
//     shifted down by 8px.
//   - Top Metadata Row: Formatted Date (e.g. "Tue, 1 June 2026") on left, history clock
//     icon + Time (e.g. "02:00 AM") on right.
//   - Title: Inter 15px w600 #333333 with Amber text match highlighting.
//   - Body Preview: Inter 11px w400 #333333 with Amber text match highlighting (max 2 lines).
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/note.dart';
import '../widgets/tactile_button.dart';

const Color _kAmberYellow   = Color(0xFFFFCC00);
const Color _kInk           = Color(0xFF333333);

class SearchNoteCard extends StatelessWidget {
  final Note note;
  final String query;
  final VoidCallback onTap;

  const SearchNoteCard({
    super.key,
    required this.note,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(note.updatedAt);
    final formattedTime = DateFormat('hh:mm a').format(note.updatedAt);

    final titleText = note.title.isEmpty ? 'Untitled Note' : note.title;
    final previewText = note.previewText;

    final baseTitleStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: _kInk,
      letterSpacing: -0.43,
    );
    final highlightTitleStyle = baseTitleStyle.copyWith(
      color: const Color(0xFFD49200),
      fontWeight: FontWeight.w700,
    );

    final baseBodyStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: _kInk,
      height: 1.40,
      letterSpacing: -0.43,
    );
    final highlightBodyStyle = baseBodyStyle.copyWith(
      color: const Color(0xFFD49200),
      fontWeight: FontWeight.w600,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: TactileButton(
        useAppleSpring: true,
        compressionScale: 0.98,
        settleDuration: const Duration(milliseconds: 600),
        onTap: onTap,
        child: Stack(
          children: [
            // 1. Yellow Accent Backing Layer (Peeking 8px Top Rim)
            Container(
              width: double.infinity,
              height: 76.0,
              decoration: BoxDecoration(
                color: _kAmberYellow,
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),

            // 2. White Front Card Sheet Layer (Shifted down 8px)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Metadata Row: Date & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _kInk,
                            letterSpacing: -0.43,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: _kInk,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: _kInk,
                                letterSpacing: -0.43,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title with Query Match Highlight
                    RichText(
                      text: TextSpan(
                        children: _buildHighlightSpans(
                          titleText,
                          query,
                          base: baseTitleStyle,
                          highlight: highlightTitleStyle,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // Body Preview with Query Match Highlight
                      RichText(
                        text: TextSpan(
                          children: _buildHighlightSpans(
                            previewText,
                            query,
                            base: baseBodyStyle,
                            highlight: highlightBodyStyle,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
