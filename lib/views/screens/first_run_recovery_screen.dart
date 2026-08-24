import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/first_run_recovery_controller.dart';
import '../../services/backup/remote_backup_metadata.dart';
import '../../services/recovery/first_run_recovery_state.dart';
import '../widgets/tactile_button.dart';

/// FirstRunRecoveryScreen — Calm, Apple-inspired recovery checkpoint screen.
///
/// Communicates to returning Google users:
/// "Your notes are safe. We found a backup. You are in control."
///
/// Invariants & Rules:
/// 1. ZERO DIRECT BUSINESS LOGIC: All state transformations and restores delegate to [FirstRunRecoveryController].
/// 2. ZERO MERGE CLAIMS: Does not claim or execute multi-device merge.
/// 3. FULL ACCESSIBILITY: Minimum 48px touch targets, high contrast, readable typography.
/// 4. RESPONSIVE: Scrollable layout with no hardcoded overflow risks.
class FirstRunRecoveryScreen extends StatefulWidget {
  final FirstRunRecoveryResult recoveryResult;
  final FirstRunRecoveryController? controller;

  const FirstRunRecoveryScreen({
    super.key,
    required this.recoveryResult,
    this.controller,
  });

  @override
  State<FirstRunRecoveryScreen> createState() => _FirstRunRecoveryScreenState();
}

class _FirstRunRecoveryScreenState extends State<FirstRunRecoveryScreen> {
  late FirstRunRecoveryController _controller;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isLocalController = true;
      _controller = FirstRunRecoveryController(
        recoveryResult: widget.recoveryResult,
      );
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isRestoring = _controller.isRestoring;
        final isCompleted = _controller.isCompleted;
        final hasFailed = _controller.hasFailed;
        final isConflict = _controller.isConflict;
        final backup = _controller.recommendedBackup;
        final localSummary = _controller.localSummary;

        return PopScope(
          canPop: !isRestoring,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // When restoring, back navigation is safely blocked.
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF2F2F7),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── 1. Top Eyebrow & Header ─────────────────────────────
                    _buildEyebrowBadge(),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome back.',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We found a Quick Notes backup from your previous session. Choose how you would like to proceed.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.45,
                        color: const Color(0xFF6E6E73),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── 2. Recommended Backup Card ──────────────────────────
                    if (backup != null) ...[
                      _buildBackupSummaryCard(backup),
                      const SizedBox(height: 16),
                    ],

                    // ── 3. State-Specific Notice (Conflict vs Clean) ────────
                    if (isConflict)
                      _buildConflictNotice(localSummary)
                    else
                      _buildCleanNotice(),
                    const SizedBox(height: 20),

                    // ── 4. Restore Failure Banner (if any) ──────────────────
                    if (hasFailed) ...[
                      _buildFailureBanner(_controller.errorMessage),
                      const SizedBox(height: 20),
                    ],

                    // ── 5. Success Banner (if any) ──────────────────────────
                    if (isCompleted) ...[
                      _buildSuccessBanner(),
                      const SizedBox(height: 20),
                    ],

                    // ── 6. Action Controls ──────────────────────────────────
                    _buildActionSection(
                      isRestoring: isRestoring,
                      isCompleted: isCompleted,
                      hasFailed: hasFailed,
                      isConflict: isConflict,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── UI Sub-Builders ───────────────────────────────────────────────────────

  Widget _buildEyebrowBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RECOVERY',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: const Color(0xFF007AFF),
        ),
      ),
    );
  }

  Widget _buildBackupSummaryCard(RemoteBackupMetadata backup) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF333333).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest Cloud Backup',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(backup.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatBytes(backup.fileSizeBytes),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6E6E73),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                icon: Icons.description_outlined,
                label: '${backup.noteCount} Notes',
              ),
              _buildMetricChip(
                icon: Icons.folder_outlined,
                label: '${backup.folderCount} Folders',
              ),
              _buildMetricChip(
                icon: Icons.check_box_outlined,
                label: '${backup.taskCount} Tasks',
              ),
              if (backup.attachmentCount > 0)
                _buildMetricChip(
                  icon: Icons.attach_file_rounded,
                  label: '${backup.attachmentCount} Attachments',
                ),
            ],
          ),
          if (_controller.totalEligibleBackupsCount > 1) ...[
            const SizedBox(height: 14),
            Text(
              '+ ${_controller.totalEligibleBackupsCount - 1} older backup(s) available on Google Drive',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6E6E73)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3A3A3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictNotice(dynamic localSummary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Data Found on This Device',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You already have ${localSummary.noteCount} notes, ${localSummary.folderCount} folders, and ${localSummary.taskCount} tasks on this device. Restoring will replace local data with your cloud backup.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.35,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready for Recovery',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This device is ready to restore your notes, folders, and tasks seamlessly.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.35,
                    color: const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureBanner(String? errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage ??
                      "Something went wrong while restoring your backup.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB91C1C),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.retryRestore();
                  },
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF16A34A), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're all set.",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Your Quick Notes data is ready.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection({
    required bool isRestoring,
    required bool isCompleted,
    required bool hasFailed,
    required bool isConflict,
  }) {
    if (isCompleted) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // ── Primary Action: Restore Backup ───────────────────────────────────
        TactileButton(
          useAppleSpring: true,
          onTap: () {
            if (isRestoring || isCompleted) return;
            HapticFeedback.mediumImpact();
            _controller.restoreRecommendedBackup();
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: isRestoring
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF333333).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isRestoring
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _controller.progressMessage ?? 'Restoring backup...',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Restore Backup',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Secondary Action: Keep Local Data (Conflict Only) ────────────────
        if (isConflict && !isRestoring) ...[
          TactileButton(
            useAppleSpring: true,
            onTap: () {
              HapticFeedback.lightImpact();
              _controller.keepLocalData();
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Center(
                child: Text(
                  'Keep Local Data',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Tertiary Action: Start Fresh ────────────────────────────────────
        if (!isRestoring)
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _controller.skipAndStartFresh();
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: const Color(0xFF8E8E93),
            ),
            child: Text(
              'Start Fresh',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6E6E73),
              ),
            ),
          ),
      ],
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day}, ${dt.year} · $hour:$minute $period';
  }
}
