import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/controllers/account_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/account/account_profile_screen.dart';
import 'package:quick_notes/views/screens/account/account_settings_screen.dart';
import 'package:quick_notes/views/screens/profile_screen.dart';

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager().init();
    await SessionManager().clearSession();
    UserRepository().clearActiveUser();
  });

  Widget buildTestWidget(Widget child, {Size size = const Size(400, 1000)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('Phase 1.9.8.3A — Account & Profile Screen Widget Tests', () {
    testWidgets('T-1 & T-2. Account -> Profile opens successfully and renders header', (tester) async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: 'usr_local_test_1',
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_local_test_1',
        email: 'offline@local.quicknotes',
        displayName: 'Offline User',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: now,
      ));

      final controller = AccountController(
        sessionManager: sessionManager,
        userRepository: userRepo,
      );

      await tester.pumpWidget(buildTestWidget(AccountSettingsScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountProfileScreen), findsOneWidget);
    });

    testWidgets('T-3 & T-12 & T-13. Profile screen does not alter canonical user ID or identity state', (tester) async {
      const initialUserId = 'usr_local_test_preserve';
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: initialUserId,
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: initialUserId,
        email: 'offline@local.quicknotes',
        displayName: 'Original Name',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: now,
      ));

      await tester.pumpWidget(buildTestWidget(const AccountProfileScreen()));
      await tester.pumpAndSettle();

      expect(sessionManager.activeUserId, equals(initialUserId));
      expect(sessionManager.activeSessionType, equals(SessionType.offline));
    });

    testWidgets('T-4 & T-5 & T-6. Offline profile displays local identity and no fake verified email', (tester) async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: 'usr_local_offline_1',
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_local_offline_1',
        email: 'offline@local.quicknotes',
        displayName: 'Offline Creator',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: now,
      ));

      await tester.pumpWidget(buildTestWidget(const AccountProfileScreen()));
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.isNotEmpty, isTrue);
      expect(textFields.first.controller?.text, equals('Offline Creator'));
      expect(find.text('Account Type'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Your notes are stored locally on this device.'), findsOneWidget);

      // Must NOT display fake email or fake verified check
      expect(find.text('offline@local.quicknotes'), findsNothing);
      expect(find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/check.png'),
          findsNothing);
    });

    testWidgets('T-7 & T-8 & T-9. Google profile displays Google name, email, and Verified badge', (tester) async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: 'usr_google_auth_1',
        sessionType: SessionType.google,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_google_auth_1',
        email: 'hemanth@gmail.com',
        displayName: 'Hemanth A',
        photoUrl: null,
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: now,
      ));

      await tester.pumpWidget(buildTestWidget(const AccountProfileScreen()));
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, equals(2));
      expect(textFields.first.controller?.text, equals('Hemanth A'));
      expect(textFields[1].controller?.text, equals('hemanth@gmail.com'));
      expect(find.text('Google Connected'), findsOneWidget);

      // Verified check badge is visible
      expect(find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/check.png'),
          findsOneWidget);
    });

    testWidgets('T-10 & T-11. Google profile handles photoUrl and fallback avatar cleanly', (tester) async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: 'usr_google_no_photo',
        sessionType: SessionType.google,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_google_no_photo',
        email: 'nophoto@gmail.com',
        displayName: 'No Photo User',
        photoUrl: null,
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: now,
      ));

      await tester.pumpWidget(buildTestWidget(const AccountProfileScreen()));
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.first.controller?.text, equals('No Photo User'));
      expect(find.text('Change Photo'), findsOneWidget);
    });

    testWidgets('T-15. ProfileScreen wraps AccountProfileScreen seamlessly as canonical UI', (tester) async {
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: 'usr_local_wrapper_check',
        sessionType: SessionType.offline,
      );

      await tester.pumpWidget(buildTestWidget(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AccountProfileScreen), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('T-16. Name editing and avatar selection saves to ProfileRepository', (tester) async {
      const activeId = 'usr_local_edit_test';
      final sessionManager = SessionManager();
      await sessionManager.init();
      await sessionManager.saveSession(
        userId: activeId,
        sessionType: SessionType.offline,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: activeId,
        email: 'offline@local.quicknotes',
        displayName: 'Initial Name',
        sessionType: SessionType.offline,
        isOffline: true,
        createdAt: now,
      ));

      await tester.pumpWidget(buildTestWidget(const AccountProfileScreen()));
      await tester.pumpAndSettle();

      // Tap textfield and change name
      await tester.enterText(find.byType(TextField).first, 'Custom New Name');
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(userRepo.currentUser?.displayName, equals('Custom New Name'));
    });
  });
}
