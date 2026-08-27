import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/vault_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestNotesProvider extends NotesProvider {
  bool _mockVaultUnlocked = false;

  @override
  bool get isVaultUnlocked => _mockVaultUnlocked;

  void setMockVaultUnlocked(bool value) {
    _mockVaultUnlocked = value;
    notifyListeners();
  }

  @override
  void lockVault() {
    _mockVaultUnlocked = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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

    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(NotesProvider notesProvider, {VoidCallback? onMenuTap}) {
    return ChangeNotifierProvider<NotesProvider>.value(
      value: notesProvider,
      child: MaterialApp(
        home: VaultScreen(
          onMenuTap: onMenuTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('VaultScreen displays locked view when vault is locked', (WidgetTester tester) async {
    final notesProvider = TestNotesProvider();

    await tester.pumpWidget(createWidgetUnderTest(notesProvider));
    await tester.pumpAndSettle();

    expect(find.text("Vault"), findsOneWidget);
    expect(find.text("Vault Encrypted"), findsOneWidget);
    expect(find.text("UNLOCK VAULT"), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
  });

  testWidgets('VaultScreen displays unlocked view and allows re-locking from header', (WidgetTester tester) async {
    final notesProvider = TestNotesProvider();
    
    final note = Note(
      id: 'locked_1',
      title: 'Secret Note',
      content: 'Top secret content',
      tags: const [],
      attachments: const [],
      colorValue: 0xFFFFFFFF,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isLocked: true,
    );
    notesProvider.setNotesForTesting([note]);
    notesProvider.setMockVaultUnlocked(true);

    await tester.pumpWidget(createWidgetUnderTest(notesProvider));
    await tester.pumpAndSettle();

    expect(find.text("Vault"), findsOneWidget);
    expect(find.text("Secret Note"), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

    // Tap the re-lock button in the header
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();

    expect(notesProvider.isVaultUnlocked, isFalse);
    expect(find.text("Vault Encrypted"), findsOneWidget);
  });
}

