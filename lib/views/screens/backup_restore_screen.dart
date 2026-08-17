import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../controllers/backup_restore_controller.dart';
import '../../models/session_type.dart';
import '../../providers/notes_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../services/backup/backup_engine.dart';
import '../../services/backup/google_drive_backup_service.dart';
import '../../services/backup/restore_engine.dart';
import '../../services/session_manager.dart';
import '../widgets/cloud_delete_confirmation_dialog.dart';
import '../widgets/grouped_list_container.dart';
import '../widgets/restore_confirmation_dialog.dart';
import '../widgets/tactile_button.dart';

/// BackupRestoreScreen — UI Foundation for Local & Cloud Backup & Restore management.
/// Designed according to QuickNotes Apple-inspired visual language (GroupedListContainer, TactileButton, AppHeaderBar).
class BackupRestoreScreen extends StatefulWidget {
  final BackupRestoreController? controller;

  const BackupRestoreScreen({
    super.key,
    this.controller,
  });

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late BackupRestoreController _controller;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _isLocalController = true;
      _controller = BackupRestoreController(
        backupEngine: BackupEngine(),
        restoreEngine: RestoreEngine(),
        storageAdapter: GoogleDriveBackupService(),
        sessionManager: SessionManager(),
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
    const primaryTextColor = Color(0xFF333333);
    final sessionManager = SessionManager();
    final isGoogleAuthenticated = sessionManager.activeSessionType == SessionType.google;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isBusy = _controller.isBusy;
        final opState = _controller.operationState;
        final isCreatingLocal = opState == BackupOperationState.creatingLocalBackup;
        final lastLocalBackup = _controller.lastLocalBackupResult;

        const backgroundColor = Color(0xFFF2F2F7);

        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar (Matching Account Section)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: [
                      TactileButton(
                        useAppleSpring: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const ShapeDecoration(
                            color: Colors.white,
                            shape: OvalBorder(),
                            shadows: [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/angle_left.svg',
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Backup & Sync",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: primaryTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.43,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 8.0),

                // Content Area (White Rounded Sheet)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // Restoration Progress Stage Banner
                            if (_controller.operationState == BackupOperationState.restoring &&
                                _controller.currentRestoreStage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _controller.currentRestoreStage!,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16.0),
                            ],

                            // Error & Info Banners
                            if (_controller.errorMessage != null) ...[
                              _buildStatusBanner(
                                message: _controller.errorMessage!,
                                isError: true,
                              ),
                              const SizedBox(height: 16.0),
                            ],
                            if (_controller.infoMessage != null) ...[
                              _buildStatusBanner(
                                message: _controller.infoMessage!,
                                isError: false,
                              ),
                              const SizedBox(height: 16.0),
                            ],

                            // SECTION: Google Drive Status
                            _buildSectionHeader('GOOGLE DRIVE'),
                            const SizedBox(height: 8.0),
                            GroupedListContainer(
                              children: [
                                GroupedTile.navigation(
                                  iconPath: 'assets/icons/settings-sliders.svg',
                                  title: 'Google Drive Account',
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isGoogleAuthenticated ? const Color(0xFFE8F5E9) : const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isGoogleAuthenticated ? 'Connected' : 'Not Connected',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isGoogleAuthenticated ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20.0),

                            // SECTION: Local Backup
                            _buildSectionHeader('CREATE LOCAL BACKUP'),
                            const SizedBox(height: 8.0),
                            GroupedListContainer(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Generates a portable .qnb backup archive stored locally on your device.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF666666),
                                          height: 1.3,
                                        ),
                                      ),
                                      if (lastLocalBackup != null && lastLocalBackup.success && lastLocalBackup.filePath != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F2F7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 16),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      p.basename(lastLocalBackup.filePath!),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: primaryTextColor,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${lastLocalBackup.noteCount} Notes · ${lastLocalBackup.folderCount} Folders · ${lastLocalBackup.taskCount} Tasks · ${lastLocalBackup.attachmentCount} Attachments',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF666666),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Size: ${_formatBytes(lastLocalBackup.fileSize ?? 0)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: const Color(0xFF8E8E93),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      TactileButton(
                                        useAppleSpring: true,
                                        onTap: isBusy
                                            ? () {}
                                            : () async {
                                                HapticFeedback.lightImpact();
                                                await _controller.createLocalBackup();
                                              },
                                        child: Container(
                                          width: double.infinity,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: isBusy ? const Color(0xFFE5E5EA) : const Color(0xFF007AFF),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: isCreatingLocal
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : Text(
                                                    'Create Local Backup',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: isBusy ? const Color(0xFF8E8E93) : Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20.0),

                            // SECTION: Cloud Backup
                            _buildSectionHeader('CLOUD BACKUP'),
                            const SizedBox(height: 8.0),
                            GroupedListContainer(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Back up notes, folders, and image assets directly to Google Drive.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF666666),
                                          height: 1.3,
                                        ),
                                      ),
                                      if (_controller.lastUploadedCloudBackup != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.cloud_done, color: Color(0xFF34C759), size: 16),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      _controller.lastUploadedCloudBackup!.fileName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: const Color(0xFF1B5E20),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Size: ${_formatBytes(_controller.lastUploadedCloudBackup!.fileSizeBytes)} · Uploaded to Google Drive',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TactileButton(
                                              useAppleSpring: true,
                                              onTap: (isBusy || !isGoogleAuthenticated)
                                                  ? () {}
                                                  : () async {
                                                      HapticFeedback.lightImpact();
                                                      await _controller.uploadCloudBackup();
                                                    },
                                              child: Container(
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: (isBusy || !isGoogleAuthenticated)
                                                      ? const Color(0xFFE5E5EA)
                                                      : const Color(0xFF34C759),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: opState == BackupOperationState.uploadingCloudBackup
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        )
                                                      : Text(
                                                          'Back Up to Drive',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: (isBusy || !isGoogleAuthenticated)
                                                                ? const Color(0xFF8E8E93)
                                                                : Colors.white,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TactileButton(
                                              useAppleSpring: true,
                                              onTap: (isBusy || !isGoogleAuthenticated)
                                                  ? () {}
                                                  : () async {
                                                      HapticFeedback.lightImpact();
                                                      await _controller.fetchCloudBackups();
                                                    },
                                              child: Container(
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF2F2F7),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'View Cloud Backups',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: primaryTextColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Cloud Backup List
                                      if (_controller.operationState == BackupOperationState.loadingCloudBackups) ...[
                                        const SizedBox(height: 16),
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Fetching backups from Google Drive...',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: const Color(0xFF666666),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else if (_controller.remoteBackups.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(
                                          'AVAILABLE CLOUD BACKUPS (${_controller.remoteBackups.length})',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _controller.remoteBackups.length,
                                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final backup = _controller.remoteBackups[index];
                                            return Container(
                                              padding: const EdgeInsets.all(12.0),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF2F2F7),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          backup.fileName,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: primaryTextColor,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '${backup.noteCount} Notes · ${backup.folderCount} Folders · ${backup.taskCount} Tasks · ${_formatBytes(backup.fileSizeBytes)}',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            color: const Color(0xFF666666),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Created: ${_formatDate(backup.createdAt)}',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            color: const Color(0xFF8E8E93),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: isBusy
                                                        ? () {}
                                                        : () async {
                                                            HapticFeedback.lightImpact();
                                                            final confirmed = await CloudDeleteConfirmationDialog.show(
                                                              context,
                                                              remoteBackup: backup,
                                                            );
                                                            if (confirmed == true && mounted) {
                                                              await _controller.deleteCloudBackup(backup);
                                                            }
                                                          },
                                                    behavior: HitTestBehavior.opaque,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFFE5E5),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(
                                                        Icons.delete_outline_rounded,
                                                        color: Color(0xFFFF3B30),
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20.0),

                            // SECTION: Restore Data
                            _buildSectionHeader('RESTORE DATA', isWarning: true),
                            const SizedBox(height: 8.0),
                            GroupedListContainer(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500), size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Restoring replaces active data',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Restoring a backup replaces your active notes, folders, and tasks. A pre-restore safety snapshot will be created automatically.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF666666),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TactileButton(
                                              useAppleSpring: true,
                                              onTap: isBusy
                                                  ? () {}
                                                  : () async {
                                                      HapticFeedback.lightImpact();

                                                      File? candidateFile;
                                                      final lastLocalPath = _controller.lastLocalBackupResult?.filePath;
                                                      if (lastLocalPath != null && File(lastLocalPath).existsSync()) {
                                                        candidateFile = File(lastLocalPath);
                                                      } else {
                                                        try {
                                                          final docsDir = await getApplicationDocumentsDirectory();
                                                          final backupsDir = Directory(p.join(docsDir.path, 'backups'));
                                                          if (backupsDir.existsSync()) {
                                                            final files = backupsDir
                                                                .listSync()
                                                                .whereType<File>()
                                                                .where((f) => f.path.toLowerCase().endsWith('.qnb'))
                                                                .toList();
                                                            if (files.isNotEmpty) {
                                                              files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
                                                              candidateFile = files.first;
                                                            }
                                                          }
                                                        } catch (_) {}
                                                      }

                                                      if (candidateFile == null || !candidateFile.existsSync()) {
                                                        return;
                                                      }

                                                      final metadata = await _controller.inspectLocalBackup(candidateFile);
                                                      if (metadata == null) return;

                                                      final currentCounts = await _controller.fetchCurrentDataCounts();

                                                      if (!mounted) return;
                                                      final confirmed = await RestoreConfirmationDialog.show(
                                                        context,
                                                        remoteBackup: metadata,
                                                        currentCounts: currentCounts,
                                                      );

                                                      if (confirmed == true && mounted) {
                                                        await _controller.restoreLocalBackup(localFile: candidateFile);
                                                        if (_controller.lastRestoreResult?.success == true && mounted) {
                                                          final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                                                          final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                                                          await notesProvider.loadFolders();
                                                          await notesProvider.loadNotes();
                                                          await tasksProvider.refresh();
                                                        }
                                                      }
                                                    },
                                              child: Container(
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: isBusy ? const Color(0xFFE5E5EA) : const Color(0xFFFF9500),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Restore Local File',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: isBusy ? const Color(0xFF8E8E93) : Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TactileButton(
                                              useAppleSpring: true,
                                              onTap: isBusy
                                                  ? () {}
                                                  : () async {
                                                      HapticFeedback.lightImpact();
                                                      if (_controller.remoteBackups.isEmpty) {
                                                        await _controller.fetchCloudBackups();
                                                      }
                                                      if (_controller.remoteBackups.isEmpty) {
                                                        return;
                                                      }

                                                      final selectedBackup = _controller.remoteBackups.first;
                                                      final currentCounts = await _controller.fetchCurrentDataCounts();

                                                      if (!mounted) return;
                                                      final confirmed = await RestoreConfirmationDialog.show(
                                                        context,
                                                        remoteBackup: selectedBackup,
                                                        currentCounts: currentCounts,
                                                      );

                                                      if (confirmed == true && mounted) {
                                                        final tempDir = Directory.systemTemp.createTempSync('drive_restore_');
                                                        try {
                                                          await _controller.downloadAndRestoreCloudBackup(
                                                            remoteFileId: selectedBackup.remoteFileId,
                                                            tempDownloadDir: tempDir,
                                                          );
                                                          if (_controller.lastRestoreResult?.success == true && mounted) {
                                                            final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                                                            final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                                                            await notesProvider.loadFolders();
                                                            await notesProvider.loadNotes();
                                                            await tasksProvider.refresh();
                                                          }
                                                        } finally {
                                                          if (tempDir.existsSync()) {
                                                            try {
                                                              tempDir.deleteSync(recursive: true);
                                                            } catch (_) {}
                                                          }
                                                        }
                                                      }
                                                    },
                                              child: Container(
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: isBusy ? const Color(0xFFE5E5EA) : const Color(0xFFD97706),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Restore From Drive',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: isBusy ? const Color(0xFF8E8E93) : Colors.white,
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

  // ── Helper UI Builders ───────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isWarning ? const Color(0xFFD97706) : const Color(0xFF8E8E93),
        ),
      ),
    );
  }

  Widget _buildStatusBanner({required String message, required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE5E5) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFFF8080) : const Color(0xFFA5D6A7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => _controller.clearMessages(),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String _formatDate(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')} ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC';
  }
}
