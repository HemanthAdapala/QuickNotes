import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';

class HabitDashboardScreen extends StatelessWidget {
  final VoidCallback onMenuTap;

  const HabitDashboardScreen({
    super.key,
    required this.onMenuTap,
  });

  // Toggle checklist completion directly from Dashboard
  void _toggleHabitComplete(BuildContext context, Note note, NotesProvider provider) {
    try {
      final decoded = jsonDecode(note.content) as List<dynamic>;
      final List<Map<String, dynamic>> items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final allChecked = items.every((e) => e['checked'] == true || e['done'] == true);

      // If all checked, uncheck all. Otherwise, check all.
      final newItems = items.map((e) {
        final copy = Map<String, dynamic>.from(e);
        if (copy.containsKey('checked')) copy['checked'] = !allChecked;
        if (copy.containsKey('done')) copy['done'] = !allChecked;
        return copy;
      }).toList();

      final updatedContent = jsonEncode(newItems);
      
      // Update streak count if checking all
      int newStreak = note.habitStreak;
      if (!allChecked) {
        newStreak += 1;
      } else {
        newStreak = note.habitStreak > 0 ? note.habitStreak - 1 : 0;
      }

      provider.updateNote(note.copyWith(
        content: updatedContent,
        habitStreak: newStreak,
        habitLastCompleted: !allChecked ? DateTime.now() : null,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);
    final habitNotes = provider.notes.where((n) => n.isHabit).toList();
    final dateStr = DateFormat('MMM d').format(DateTime.now()).toUpperCase();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 768;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: isDesktop
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: onMenuTap,
              ),
        title: Text(
          "Gravity",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Screen Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Daily Intentions",
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Quiet persistence. These are the small things that hold the larger structure together.",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFEBEBE8)),
                const SizedBox(height: 24),

                // Bento Grid for Habits
                if (habitNotes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(50),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No Active Habits",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Configure any checklist note as a habit in the editor options.",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: width > 600 ? 2 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: habitNotes.length,
                    itemBuilder: (context, index) {
                      final note = habitNotes[index];
                      return _buildHabitBentoCard(context, note, provider);
                    },
                  ),
                  const SizedBox(height: 32),

                  // The Long View monthly dot matrix
                  _buildLongViewMatrix(context, habitNotes),
                ],

                const SizedBox(height: 32),
                _buildAtmosphericQuote(context),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Habits Bento card
  Widget _buildHabitBentoCard(BuildContext context, Note note, NotesProvider provider) {
    final theme = Theme.of(context);

    // Calculate checklist completion progress
    int total = 0;
    int checked = 0;
    try {
      final decoded = jsonDecode(note.content) as List;
      total = decoded.length;
      checked = decoded.where((item) => item['checked'] == true || item['done'] == true).length;
    } catch (_) {}

    final progress = total == 0 ? 0.0 : (checked / total);
    final isCompleted = progress == 1.0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : "Untitled Habit",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "$checked of $total done",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleHabitComplete(context, note, provider),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted ? theme.colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? Colors.transparent : theme.dividerColor.withAlpha(180),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: isCompleted ? Colors.white : theme.colorScheme.primary.withAlpha(120),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Current Streak",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
              Text(
                "${note.habitStreak} Days",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Monthly Overview section
  Widget _buildLongViewMatrix(BuildContext context, List<Note> habits) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "The Long View",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem(theme.colorScheme.primary, "Completed"),
                    const SizedBox(width: 12),
                    _buildLegendItem(theme.dividerColor.withAlpha(200), "Missed"),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEBEBE8)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: habits.map((habit) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            habit.title,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(31, (dayIndex) {
                            // Seeded complete/miss logic based on day and streak
                            // Let days up to the current streak count as completed
                            final isDone = dayIndex < habit.habitStreak;
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2.0),
                              decoration: BoxDecoration(
                                color: isDone ? theme.colorScheme.primary : theme.dividerColor,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEBEBE8)),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: theme.cardColor,
            alignment: Alignment.center,
            child: Text(
              "Export Monthly Report (PDF)",
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF91918E))),
      ],
    );
  }

  // Ambient zen photo section
  Widget _buildAtmosphericQuote(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network(
            "https://lh3.googleusercontent.com/aida-public/AB6AXuDm9OojUNy8UzXsfALNwZHLD4b9mGJCoBBBNcfO3DWW9a8kpI2CjbED9LPdcB5vsuQu7ApLwFdwKGr6dgQIqiux4zxOO1AlhecQQKG9_OcA4431jcHVl3ec6zlOKnUz1cr7iOhh6_MMwrwXO5pfO57FO9dY8jHtpZF_48RfWUEpOHkArpdLlN0PGgT-XDdWZRS2YUGm7wN0COgLn55D4UewLv4zhlFhBrwrCTs8eAgfI4KXBRP2iOmBt2d6fmQlRreltK4SonKwEbg",
            fit: BoxFit.cover,
            height: 160,
            width: double.infinity,
          ),
          Container(
            color: Colors.black.withAlpha(40),
            height: 160,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "\"We are what we repeatedly do. Excellence, then, is not an act, but a habit.\"",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
