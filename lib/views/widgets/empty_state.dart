import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';

class EmptyState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const EmptyState({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final notesProvider = Provider.of<NotesProvider>(context);
    final view = notesProvider.currentView;

    // Set configuration variables based on current view
    IconData visualIcon;
    String titleText;
    String subtitleText;
    Color containerColor;

    if (view == NotesViewType.archive) {
      visualIcon = icon ?? Icons.archive_outlined;
      titleText = title ?? "Archive is empty";
      subtitleText = subtitle ??
          "Move notes here to declutter your dashboard without losing them permanently.";
      containerColor = theme.colorScheme.secondaryContainer;
    } else if (view == NotesViewType.favorites) {
      visualIcon = icon ?? Icons.star_outline_rounded;
      titleText = title ?? "No favorites yet";
      subtitleText = subtitle ??
          "Mark important notes as favorites to gather them here in one place.";
      containerColor = theme.colorScheme.tertiaryContainer;
    } else if (view == NotesViewType.trash) {
      visualIcon = icon ?? Icons.delete_outline_rounded;
      titleText = title ?? "Trash is empty";
      subtitleText = subtitle ??
          "Notes you delete will appear here before being permanently purged.";
      containerColor = theme.colorScheme.errorContainer;
    } else {
      visualIcon = icon ?? Icons.edit_document;
      titleText = title ?? "Your thoughts are empty";
      subtitleText = subtitle ??
          "Capture your ideas, organize tasks, and pin important memories. Tap the button below to write your first note.";
      containerColor = theme.colorScheme.primaryContainer;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom modern visual illustration using nested shapes
            Stack(
              alignment: Alignment.center,
              children: [
                // Background outer ring
                Container(
                  width: size.width * 0.45,
                  height: size.width * 0.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        containerColor.withAlpha(120),
                        theme.colorScheme.surface.withAlpha(0),
                      ],
                    ),
                  ),
                ),
                // Decorative floating card 1
                Transform.rotate(
                  angle: -0.15,
                  child: Container(
                    width: 110,
                    height: 140,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(150),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF333333).withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(-4, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                // Decorative floating card 2 (Note)
                Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    width: 110,
                    height: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withAlpha(20),
                          blurRadius: 15,
                          offset: const Offset(4, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(180),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 70,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 45,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            visualIcon,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Floating pencil/marker icon (show only on feed view)
                if (view == NotesViewType.feed)
                  Positioned(
                    bottom: 10,
                    right: size.width * 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.secondary.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.border_color_rounded,
                        size: 18,
                        color: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // Title text
            Text(
              titleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle text
            Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
