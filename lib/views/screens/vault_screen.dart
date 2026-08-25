import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/notes_provider.dart';
import '../../models/note.dart';
import '../widgets/pin_lock_sheet.dart';
import '../widgets/tactile_button.dart';
import 'note_editor_screen.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/bottom_sheet_transition.dart';
import '../widgets/app_header_bar.dart';

class VaultScreen extends StatelessWidget {
  final VoidCallback onMenuTap;

  const VaultScreen({
    super.key,
    required this.onMenuTap,
  });

  // Helper to check PIN
  void _triggerUnlock(BuildContext context, NotesProvider provider) {
    showAnimatedBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      child: PinLockSheet(
        onPinSubmitted: (pin) async {
          final success = await provider.unlockVault(pin);
          if (!context.mounted) return;
          if (!success) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Incorrect PIN! Access Denied."),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);
    final isUnlocked = provider.isVaultUnlocked;

    // Filter locked notes (in-memory provider lists them decrypted when unlocked, scrubbed when locked)
    final lockedNotes = provider.notes.where((note) => note.isLocked).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_vault_menu',
                rightHeroTag: 'hero_vault_action',
                leftWidth: 44.0,
                rightWidth: 44.0,
                onLeftTap: onMenuTap,
                leftChild: Icon(
                  Icons.menu_rounded,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1C1C1E),
                  size: 24,
                ),
                titleWidget: Text(
                  "Vault",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1C1C1E),
                  ),
                ),
                rightChild: isUnlocked
                    ? Icon(
                        Icons.lock_open_rounded,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF1C1C1E),
                        size: 24,
                      )
                    : null,
                onRightTap: isUnlocked
                    ? () {
                        HapticFeedback.lightImpact();
                        provider.lockVault();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Vault re-locked")),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 24.0),
            Expanded(
              child: isUnlocked
                  ? _buildUnlockedContent(context, provider, lockedNotes)
                  : _buildLockedOverlay(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  // Locked State overlay
  Widget _buildLockedOverlay(BuildContext context, NotesProvider provider) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating fingerprint circle
            GestureDetector(
              onTap: () => _triggerUnlock(context, provider),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Vault Encrypted",
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                "Your most sensitive thoughts are protected with end-to-end encryption. Verify your identity to enter.",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _triggerUnlock(context, provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
                elevation: 0,
              ),
              child: Text(
                "UNLOCK VAULT",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.dividerColor,
                        ),
                      )),
            ),
          ],
        ),
      ),
    );
  }

  // Unlocked state content canvas
  Widget _buildUnlockedContent(
      BuildContext context, NotesProvider provider, List<Note> notes) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final gridCount = width > 600 ? 2 : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Empty locked notes handler
              if (notes.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurface.withAlpha(50)),
                        const SizedBox(height: 16),
                        Text(
                          "No Secured Notes Yet",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withAlpha(120),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Lock individual notes in the editor to view them in the vault.",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withAlpha(100),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Bento Grid for locked items
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _buildVaultBentoCard(context, note, provider);
                  },
                ),
              ],
              const SizedBox(height: 16),

              // Fixed status cards matching vault mockup
              const SizedBox(height: 16),
              _buildEncryptionStatusCard(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Bento Card representing a decrypted secure note
  Widget _buildVaultBentoCard(
      BuildContext context, Note note, NotesProvider provider) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('MMMM d, yyyy').format(note.updatedAt).toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          buildPageRoute(NoteEditorScreen(note: note)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isNotEmpty ? note.title : "Untitled",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      note.content.startsWith('[')
                          ? "[Checklist items]"
                          : (note.content.isNotEmpty
                              ? note.content
                              : "Empty content"),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(160),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: note.tags
                    .take(2)
                    .map((tag) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Decoupled status widget to match mockup Item 5
  Widget _buildEncryptionStatusCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ENCRYPTION LEVEL",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "AES-256",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Icon(
            Icons.verified_user_outlined,
            color: theme.colorScheme.onSurface.withAlpha(120),
            size: 28,
          ),
        ],
      ),
    );
  }
}

