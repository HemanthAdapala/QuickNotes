import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/views/widgets/restore_confirmation_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    late final MessageHandler fontHandler;
    fontHandler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', fontHandler);
      }
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', fontHandler);
  });

  group('Phase 1.9.6.6 — RestoreConfirmationDialog Widget Tests', () {
    final mockBackup = RemoteBackupMetadata(
      remoteFileId: 'drive_file_123',
      fileName: 'quick_notes_backup_20260814_120000.qnb',
      fileSizeBytes: 204800,
      createdAt: DateTime.utc(2026, 8, 14, 12, 0, 0),
      backupId: 'bkp_123',
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 15,
      folderCount: 3,
      taskCount: 8,
      attachmentCount: 4,
      providerUserIdHash: 'hash_abc',
      sha256Checksum: 'sha_abc',
    );

    final mockCurrentCounts = {
      'notes': 42,
      'folders': 7,
      'tasks': 19,
      'attachments': 12,
    };

    testWidgets('1. Dialog renders title, metrics table, safety notice, and action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => RestoreConfirmationDialog.show(
                  context,
                  remoteBackup: mockBackup,
                  currentCounts: mockCurrentCounts,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('RESTORE BACKUP'), findsOneWidget);
      expect(find.text('quick_notes_backup_20260814_120000.qnb'), findsOneWidget);
      expect(find.textContaining('Restoring this backup will replace the current'), findsOneWidget);
      expect(find.textContaining('A safety snapshot of your current data will be created'), findsOneWidget);

      // Metrics
      expect(find.text('42'), findsOneWidget); // Current notes
      expect(find.text('15'), findsOneWidget); // Backup notes
      expect(find.text('7'), findsOneWidget);  // Current folders
      expect(find.text('3'), findsOneWidget);  // Backup folders

      // Buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Restore Backup'), findsOneWidget);
    });

    testWidgets('2. Tapping Cancel pops dialog with false', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await RestoreConfirmationDialog.show(
                    context,
                    remoteBackup: mockBackup,
                    currentCounts: mockCurrentCounts,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals(false));
    });

    testWidgets('3. Tapping Restore Backup pops dialog with true', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await RestoreConfirmationDialog.show(
                    context,
                    remoteBackup: mockBackup,
                    currentCounts: mockCurrentCounts,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore Backup'));
      await tester.pumpAndSettle();

      expect(dialogResult, equals(true));
    });
  });
}
