import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart';

import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/models/session_type.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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

    SharedPreferences.setMockInitialValues({});
    final session = SessionManager();
    await session.init();
    await session.saveSession(userId: 'usr_test_folder', sessionType: SessionType.offline);
  });

  test('NotesProvider deleteFolder database logic test', () async {
    final provider = NotesProvider();
    await provider.loadFolders();
    
    // Clear existing folders
    for (final folder in List.from(provider.folders)) {
      await provider.deleteFolder(folder.id);
    }
    expect(provider.folders.isEmpty, isTrue);

    // Create a folder
    await provider.createFolder('Sprint 14 Test Folder');
    expect(provider.folders.length, 1);
    expect(provider.folders.first.name, 'Sprint 14 Test Folder');
    final folderId = provider.folders.first.id;

    // Delete the folder
    await provider.deleteFolder(folderId);
    expect(provider.folders.isEmpty, isTrue);
  });
}
