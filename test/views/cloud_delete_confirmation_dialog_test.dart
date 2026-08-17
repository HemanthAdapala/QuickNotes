import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:quick_notes/services/backup/remote_backup_metadata.dart';
import 'package:quick_notes/views/widgets/cloud_delete_confirmation_dialog.dart';

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

  group('Phase 1.9.6.8 — CloudDeleteConfirmationDialog Widget Tests', () {
    final mockBackup = RemoteBackupMetadata(
      remoteFileId: 'drive_del_file_99',
      fileName: 'quick_notes_backup_20260814_140000.qnb',
      fileSizeBytes: 1048576,
      createdAt: DateTime.utc(2026, 8, 14, 14, 0, 0),
      backupId: 'bkp_del_99',
      formatVersion: 1,
      databaseSchemaVersion: 18,
      appVersion: '1.0.0',
      noteCount: 10,
      folderCount: 2,
      taskCount: 5,
      attachmentCount: 1,
      providerUserIdHash: 'hash_del',
      sha256Checksum: 'sha_del',
    );

    testWidgets('1. Dialog renders title, filename, metadata, warning text, and action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CloudDeleteConfirmationDialog.show(
                  context,
                  remoteBackup: mockBackup,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('DELETE CLOUD BACKUP'), findsOneWidget);
      expect(find.text('quick_notes_backup_20260814_140000.qnb'), findsOneWidget);
      expect(find.textContaining('10 Notes · 2 Folders · 5 Tasks'), findsOneWidget);
      expect(find.textContaining('This will permanently delete this backup file'), findsOneWidget);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Backup'), findsOneWidget);
    });

    testWidgets('2. Tapping Cancel pops dialog with false', (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CloudDeleteConfirmationDialog.show(
                    context,
                    remoteBackup: mockBackup,
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

      expect(result, equals(false));
    });

    testWidgets('3. Tapping Delete Backup pops dialog with true', (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CloudDeleteConfirmationDialog.show(
                    context,
                    remoteBackup: mockBackup,
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

      await tester.tap(find.text('Delete Backup'));
      await tester.pumpAndSettle();

      expect(result, equals(true));
    });
  });
}
