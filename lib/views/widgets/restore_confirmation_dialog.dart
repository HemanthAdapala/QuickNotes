import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backup/remote_backup_metadata.dart';
import 'tactile_button.dart';

/// RestoreConfirmationDialog — Modal dialog presenting pre-restore impact details.
///
/// Principles:
/// 1. CLEAR DESTRUCTIVE WARNING: Prominently warns user that current data will be replaced.
/// 2. METRIC COMPARISON: Compares current entity counts against backup entity counts.
/// 3. SAFETY GUARANTEE: Explains that a pre-restore safety snapshot will be created.
/// 4. QUICK NOTES UI LANGUAGE: Uses Inter typography, 28px rounded corners, and tactile buttons.
class RestoreConfirmationDialog extends StatelessWidget {
  final RemoteBackupMetadata remoteBackup;
  final Map<String, int> currentCounts;

  const RestoreConfirmationDialog({
    super.key,
    required this.remoteBackup,
    required this.currentCounts,
  });

  static Future<bool?> show(
    BuildContext context, {
    required RemoteBackupMetadata remoteBackup,
    required Map<String, int> currentCounts,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RestoreConfirmationDialog(
        remoteBackup: remoteBackup,
        currentCounts: currentCounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNotes = currentCounts['notes'] ?? 0;
    final currentFolders = currentCounts['folders'] ?? 0;
    final currentTasks = currentCounts['tasks'] ?? 0;
    final currentAttachments = currentCounts['attachments'] ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      elevation: 0,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20.0),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
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
              // Header Title & Warning Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESTORE BACKUP',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          remoteBackup.fileName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF4B5563),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Warning Notice
              Text(
                'Restoring this backup will replace the current notes, folders, and tasks on this device.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: const Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Comparison Table Container
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Metric',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'Current',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'Backup',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12, thickness: 1),
                    _buildMetricRow('Notes', currentNotes, remoteBackup.noteCount),
                    const SizedBox(height: 6),
                    _buildMetricRow('Folders', currentFolders, remoteBackup.folderCount),
                    const SizedBox(height: 6),
                    _buildMetricRow('Tasks', currentTasks, remoteBackup.taskCount),
                    const SizedBox(height: 6),
                    _buildMetricRow('Attachments', currentAttachments, remoteBackup.attachmentCount),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Safety Snapshot Notice
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A safety snapshot of your current data will be created automatically before restore.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF065F46),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons (Cancel / Restore Backup)
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
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
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
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Restore Backup',
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

  Widget _buildMetricRow(String label, int current, int backup) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(
            '$backup',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF059669),
            ),
          ),
        ),
      ],
    );
  }
}
