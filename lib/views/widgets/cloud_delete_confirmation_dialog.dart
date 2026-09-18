import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backup/remote_backup_metadata.dart';
import 'tactile_button.dart';

/// CloudDeleteConfirmationDialog — Modal dialog confirming permanent deletion of a Google Drive cloud backup.
///
/// Principles:
/// 1. CLEAR DESTRUCTIVE CONFIRMATION: Clearly states file details and permanent remote deletion.
/// 2. QUICK NOTES DESIGN LANGUAGE: Inter typography, 28px rounded corners, and tactile buttons.
class CloudDeleteConfirmationDialog extends StatelessWidget {
  final RemoteBackupMetadata remoteBackup;

  const CloudDeleteConfirmationDialog({
    super.key,
    required this.remoteBackup,
  });

  static Future<bool?> show(
    BuildContext context, {
    required RemoteBackupMetadata remoteBackup,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CloudDeleteConfirmationDialog(
        remoteBackup: remoteBackup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF374151);
    final secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF4B5563);
    final detailsCardBg = isDark ? const Color(0xFF242426) : const Color(0xFFF9FAFB);
    final detailsCardBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final cancelBtnBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF3F4F6);
    final cancelBtnBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB);
    final cancelBtnTextColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF4B5563);
    final destructiveColor = isDark ? const Color(0xFFFF453A) : const Color(0xFFDC2626);
    final destructiveIconBg = isDark ? const Color(0x33FF453A) : const Color(0xFFFEE2E2);
    final destructiveTitleColor = isDark ? const Color(0xFFFF453A) : const Color(0xFF991B1B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      elevation: 0,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20.0),
        decoration: ShapeDecoration(
          color: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: isDark ? const BorderSide(color: Color(0xFF2C2C2E), width: 1.0) : BorderSide.none,
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & Red Trash Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: destructiveIconBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.delete_forever_outlined,
                      color: destructiveColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELETE CLOUD BACKUP',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: destructiveTitleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          remoteBackup.fileName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // File Details Card
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: detailsCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: detailsCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${remoteBackup.noteCount} Notes · ${remoteBackup.folderCount} Folders · ${remoteBackup.taskCount} Tasks',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Size: ${_formatBytes(remoteBackup.fileSizeBytes)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Permanent Warning Text
              Text(
                'This will permanently delete this backup file from your Google Drive storage. This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Buttons Row (Cancel / Delete Backup)
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: cancelBtnBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cancelBtnBorder),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cancelBtnTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TactileButton(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: destructiveColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Delete Backup',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
