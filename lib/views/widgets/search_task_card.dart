// ──────────────────────────────────────────────────────────────────────────────
// search_task_card.dart — Search Task Result Card Widget
//
// DESIGN SPECIFICATION (Figma "Global Search Screen Tasks"):
//   - Dual-layer stack with peeking top accent rim: Electric Blue backing container
//     (Color(0xFF0088FF), 20px radius) with white front card (Colors.white, 20px radius)
//     shifted down by 8px.
//   - Top Metadata Row: Formatted Date (e.g. "Tue, 1 June 2026") on left, history clock
//     icon + Time (e.g. "02:00 AM") on right.
//   - Task Title Row: Inter 15px w500 #333333 with Amber text match highlighting.
//   - Priority Badge (if priority != 'None'): Grey background (Color(0xFFF2F2F7)),
//     Red text (Color(0xFFFF383C)), 10px Inter w600, radius 40px.
//   - Recurrence Badge (if recurring): Grey background (Color(0xFFF2F2F7)),
//     Red text (Color(0xFFFF383C)), 10px Inter w600, radius 40px.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/task_item.dart';
import '../../models/repeat_rule.dart';
import '../widgets/tactile_button.dart';

const Color _kAccentsBlue    = Color(0xFF0088FF);
const Color _kAccentsRed     = Color(0xFFFF383C);
const Color _kInk            = Color(0xFF333333);
const Color _kBgSecondary    = Color(0xFFF2F2F7);

class SearchTaskCard extends StatelessWidget {
  final TaskItem task;
  final String query;
  final VoidCallback onTap;

  const SearchTaskCard({
    super.key,
    required this.task,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayDate = task.reminderTime ?? task.dueDate;
    final formattedDate = DateFormat('EEE, d MMMM yyyy').format(displayDate.toLocal());
    final formattedTime = DateFormat('hh:mm a').format(displayDate.toLocal());

    final titleText = task.title.isEmpty ? 'Untitled Task' : task.title;

    final baseTitleStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _kInk,
      letterSpacing: -0.43,
    );
    final highlightTitleStyle = baseTitleStyle.copyWith(
      color: const Color(0xFFD49200),
      fontWeight: FontWeight.w700,
    );

    final showPriority = task.priority != 'None' && task.priority.isNotEmpty;
    final showRecurrence = task.repeatRule != RepeatRule.none || task.isRecurring;
    final recurrenceLabel = _repeatRuleLabel(task.repeatRule);

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
            // 1. Electric Blue Accent Backing Layer (Peeking 8px Top Rim)
            Container(
              width: double.infinity,
              height: 76.0,
              decoration: BoxDecoration(
                color: _kAccentsBlue,
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),

            // 2. White Front Card Sheet Layer (Shifted down 8px)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                    const SizedBox(height: 8),

                    // Title & Badges Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Task Title with Query Match Highlight
                        Expanded(
                          child: RichText(
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
                        ),

                        // Badges Row
                        if (showPriority || showRecurrence) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showPriority) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _kBgSecondary,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Text(
                                    task.priority == 'High' ? '🚩 High' : task.priority,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _kAccentsRed,
                                      letterSpacing: -0.43,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (showRecurrence) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _kBgSecondary,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Text(
                                    recurrenceLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _kAccentsRed,
                                      letterSpacing: -0.43,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _repeatRuleLabel(RepeatRule rule) {
    switch (rule) {
      case RepeatRule.daily:   return 'Daily';
      case RepeatRule.weekly:  return 'Weekly';
      case RepeatRule.monthly: return 'Monthly';
      case RepeatRule.yearly:  return 'Yearly';
      default:                 return 'Recurring';
    }
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
