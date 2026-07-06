import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../../themes/quick_notes_theme.dart';
import '../../providers/notes_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);

    // Calculate quick stats
    final totalNotes = provider.notes.length;
    final favoriteNotes = provider.notes.where((n) => n.isFavorite).length;
    final lockedNotes = provider.notes.where((n) => n.isLocked).length;
    final totalHabits = provider.notes.where((n) => n.isHabit).length;

    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AppHeaderBar(
                leftWidth: 44.0,
                onLeftTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                title: "User Profile",
                titleColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: QuickNotesTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: QuickNotesTheme.border, width: 2),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                "https://lh3.googleusercontent.com/aida-public/AB6AXuDDDbQZzHFjLe7KbAj3WunCYWwKUAItyNOmSjwEoxaZ0lZwWUGVR10nWRi2_2Qsju87gb_NkMf9lyXW-xL2K5sJWeN7U-fXtKBz1NnoHsEZ_4KEn8XE99nAUeXVp5l6BTaoAN3eL9Gs22HWHjSL4KAWxINtItIJiO7Tay0yEH-jHZKEHqJGRTnHE5nRItgTWXB5OQPuTwfPv5_cQ0y265VWgIPaXiQp8zeMGB_UZKhH3Het-6uFten02P886jXShg1g4C0wA3-XszY",
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.person_outline_rounded,
                                  size: 48,
                                  color: QuickNotesTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Julian Thorne",
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: QuickNotesTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Pro Member since August 2023",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: QuickNotesTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      Text(
                        "STATISTICS",
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bento Grid for Stats
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.3,
                        children: [
                          _buildStatTile(context, "TOTAL NOTES", totalNotes.toString(), Icons.note_alt_outlined),
                          _buildStatTile(context, "FAVORITES", favoriteNotes.toString(), Icons.star_border_rounded),
                          _buildStatTile(context, "LOCKED NOTES", lockedNotes.toString(), Icons.lock_outline_rounded),
                          _buildStatTile(context, "ACTIVE HABITS", totalHabits.toString(), Icons.check_circle_outline_rounded),
                        ],
                      ),
                      const SizedBox(height: 40),

                      Text(
                        "ACCOUNT DETAILS",
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Simple account details list
                      _buildDetailRow("Email", "julian.thorne@luxury.com"),
                      _buildDetailRow("Subscription", "QuickNotes Pro (\$9.99/mo)"),
                      _buildDetailRow("Next Billing Date", "July 12, 2026"),
                      _buildDetailRow("Storage Used", "14.2 MB of 10 GB"),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuickNotesTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuickNotesTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: QuickNotesTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 16, color: QuickNotesTheme.accent),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 28,
              color: QuickNotesTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: QuickNotesTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: QuickNotesTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: QuickNotesTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
