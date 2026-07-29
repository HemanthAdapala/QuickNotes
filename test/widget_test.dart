import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/main.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/splash_screen.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/providers/tasks_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;

    // Intercept Google Fonts asset requests and return dummy bytes to prevent exceptions.
    // Non-font asset requests (like AssetManifest.bin) are forwarded back to the default handler.
    late final MessageHandler handler;
    handler = (ByteData? message) async {
      if (message == null) return null;
      final Uint8List list = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(list);
      if (key.startsWith('google_fonts/')) {
        return ByteData(16); // Return dummy bytes to satisfy allowRuntimeFetching = false
      }

      // Bypass our mock handler to delegate to the default test asset handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      try {
        return await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .send('flutter/assets', message);
      } finally {
        // Restore our handler
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', handler);
      }
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);

    const MethodChannel sqfliteChannel = MethodChannel('plugins.flutter.io/sqflite');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sqfliteChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        return '.';
      }
      if (methodCall.method == 'openDatabase') {
        return <String, dynamic>{'id': 1};
      }
      if (methodCall.method == 'query') {
        return <Map<String, dynamic>>[];
      }
      if (methodCall.method == 'execute') {
        return null;
      }
      return null;
    });

    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    const MethodChannel notificationsChannel = MethodChannel('dexterous.com/flutter_local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (MethodCall methodCall) async {
      return true;
    });

    const MethodChannel homeWidgetChannel = MethodChannel('class.yiss.home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (MethodCall methodCall) async {
      return true;
    });
  });

  testWidgets('App dashboard loading smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => TasksProvider()),
        ],
        child: const QuickNotesApp(),
      ),
    );

    // Allow the async database loading to resolve and trigger a rebuild
    await tester.idle();
    await tester.pump();

    // Verify that our app main title loads
    expect(find.byType(SplashScreen), findsOneWidget);

    // Settle pending timers/animations to avoid test framework warnings
    await tester.pump(const Duration(seconds: 3));
  });

  test('FolderUtils cycle detection unit test', () {
    final folderA = Folder(
      id: 'A',
      name: 'Folder A',
      parentId: 'B',
      createdAt: DateTime.now(),
    );
    final folderB = Folder(
      id: 'B',
      name: 'Folder B',
      parentId: 'A',
      createdAt: DateTime.now(),
    );

    // This should detect the cycle and not throw stack overflow
    final result = FolderUtils.getHierarchicalFolders([folderA, folderB]);

    expect(result, isNotNull);
    // Circular folders shouldn't be duplicated or loop forever.
    // In this cycle, traversed folders from root traverse will be empty since parentIds are non-null.
    // In orphan traverse:
    // folderA has parent B. B is in folders list, so folderA isn't an orphan.
    // folderB has parent A. A is in folders list, so folderB isn't an orphan.
    // Thus result should be empty, but most importantly, not crash.
    expect(result.length, equals(0));
  });
}
