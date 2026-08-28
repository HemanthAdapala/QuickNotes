import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../../themes/quick_notes_theme.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';
import '../../repositories/notes_repository.dart';

class ExportImportScreen extends StatelessWidget {
  const ExportImportScreen({super.key});

  // Export entire workspace as a stringified JSON file
  Future<void> _exportWorkspace(
      BuildContext context, NotesProvider provider) async {
    try {
      final allNotes = await SqliteNotesRepository().getNotes();
      final List<Map<String, dynamic>> notesMap =
          allNotes.map((n) => n.toMap()).toList();
      final backupString = jsonEncode(notesMap);

      // Share backup file directly using Share API
      await SharePlus.instance.share(
        ShareParams(
          text: backupString,
          subject: 'QuickNotes_Workspace_Backup.json',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  // Mock import workspace from raw text input
  void _importWorkspaceDialog(BuildContext context, NotesProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickNotesTheme.surface,
        title: const Text("Import Backup JSON"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Paste the raw JSON backup string from your exported QuickNotes file below:",
              style:
                  TextStyle(fontSize: 13, color: QuickNotesTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              style:
                  const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
              decoration: const InputDecoration(
                hintText: "[{...}, {...}]",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL",
                style: TextStyle(color: QuickNotesTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final rawJson = controller.text.trim();
                if (rawJson.isEmpty) return;

                final List<dynamic> decoded =
                    jsonDecode(rawJson) as List<dynamic>;
                int importCount = 0;
                for (var map in decoded) {
                  final noteMap = Map<String, dynamic>.from(map as Map);
                  final note = Note.fromMap(noteMap);
                  await provider.importNote(note);
                  importCount++;
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text("Successfully imported $importCount notes")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Import failed: invalid JSON ($e)")),
                );
              }
            },
            child: const Text("IMPORT",
                style: TextStyle(color: QuickNotesTheme.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
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
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                title: "Backup & Sharing",
                titleColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: Align(
                   alignment: Alignment.topCenter,
                   child: ConstrainedBox(
                   constraints: const BoxConstraints(maxWidth: 402.0),
                   child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 8.0, bottom: 8.0 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("EXPORT WORKSPACE"),
                      const SizedBox(height: 12),

                      _buildActionCard(
                        context,
                        title: "Share Workspace Backup",
                        description:
                            "Export all notes, folders, and attachments as a JSON string file that you can share or save to drive.",
                        icon: Icons.backup_outlined,
                        onTap: () => _exportWorkspace(context, provider),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle("IMPORT WORKSPACE"),
                      const SizedBox(height: 12),

                      _buildActionCard(
                        context,
                        title: "Restore Backup JSON",
                        description:
                            "Import notes from a previously shared JSON workspace file to restore your database.",
                        icon: Icons.restore_page_outlined,
                        onTap: () => _importWorkspaceDialog(context, provider),
                      ),
                      const SizedBox(height: 40),

                      // Export advice note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: QuickNotesTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: QuickNotesTheme.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: QuickNotesTheme.accent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Workspace backups do not contain secure vault passwords. Secure vault notes will remain encrypted with your master key when imported to another device.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: QuickNotesTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: QuickNotesTheme.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: QuickNotesTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: QuickNotesTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: QuickNotesTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: QuickNotesTheme.border),
              ),
              child: Icon(icon, color: QuickNotesTheme.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: QuickNotesTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QuickNotesTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: QuickNotesTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
