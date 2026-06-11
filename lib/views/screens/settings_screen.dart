import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notes_provider.dart';

class SettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback onMenuTap;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          "QuickNotes",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Center(
              child: Text(
                "SETTINGS",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Section
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        "https://lh3.googleusercontent.com/aida-public/AB6AXuDDDbQZzHFjLe7KbAj3WunCYWwKUAItyNOmSjwEoxaZ0lZwWUGVR10nWRi2_2Qsju87gb_NkMf9lyXW-xL2K5sJWeN7U-fXtKBz1NnoHsEZ_4KEn8XE99nAUeXVp5l6BTaoAN3eL9Gs22HWHjSL4KAWxINtItIJiO7Tay0yEH-jHZKEHqJGRTnHE5nRItgTWXB5OQPuTwfPv5_cQ0y265VWgIPaXiQp8zeMGB_UZKhH3Het-6uFten02P886jXShg1g4C0wA3-XszY",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Julian Thorne",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            "Pro Account — Member since 2023",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: theme.dividerColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        "MANAGE",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEBEBE8)),
                const SizedBox(height: 24),

                // Settings Group: Workspace
                _buildSectionTitle("WORKSPACE"),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: "Appearance",
                  subtitle: isDarkMode ? "Dark Mode" : "Light Mode",
                  onTap: onThemeToggle,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.text_fields_rounded,
                  title: "Typography",
                  subtitle: "Inter & Mono",
                  onTap: () {},
                ),
                _buildSwitchTile(
                  context,
                  icon: Icons.auto_awesome,
                  title: "Zen Focus Mode",
                  description: "Hide all chrome while writing",
                  value: Provider.of<NotesProvider>(context).isZenModeEnabled,
                  onChanged: (val) {
                    Provider.of<NotesProvider>(context, listen: false).setZenMode(val);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFEBEBE8)),
                const SizedBox(height: 24),

                // Settings Group: Security & Sync
                _buildSectionTitle("SECURITY & SYNC"),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context,
                  icon: Icons.lock_outline_rounded,
                  title: "Vault Encryption",
                  subtitle: "Enabled",
                  onTap: () {},
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.cloud_done_outlined,
                  title: "Cloud Sync",
                  subtitle: "Last synced 2m ago",
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFEBEBE8)),
                const SizedBox(height: 24),

                // Settings Group: Advanced
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("ADVANCED"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        "BETA",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context,
                  icon: Icons.terminal_rounded,
                  title: "Developer API",
                  trailing: Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.onSurface.withAlpha(120)),
                  onTap: () {},
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.archive_outlined,
                  title: "Export Workspace",
                  subtitle: "JSON, Markdown",
                  onTap: () {},
                ),
                const SizedBox(height: 32),

                // Logout button
                OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withAlpha(40)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(
                    "Log Out of QuickNotes",
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "Version 2.4.0 — Made with focus in Stockholm.",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF91918E),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.onSurface.withAlpha(150)),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.primary),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(120)),
            )
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withAlpha(80)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return StatefulBuilder(
      builder: (context, setState) {
        bool localValue = value;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: theme.colorScheme.onSurface.withAlpha(150)),
          title: Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, color: theme.colorScheme.primary),
          ),
          subtitle: Text(
            description,
            style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(120)),
          ),
          trailing: Switch.adaptive(
            value: localValue,
            activeThumbColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withAlpha(80),
            onChanged: (val) {
              setState(() {
                localValue = val;
              });
              onChanged(val);
            },
          ),
        );
      },
    );
  }
}
