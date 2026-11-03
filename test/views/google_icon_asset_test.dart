import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/controllers/account_controller.dart';
import 'package:quick_notes/controllers/login_controller.dart';
import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/account/account_settings_screen.dart';
import 'package:quick_notes/views/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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
    await SessionManager().clearSession();
    UserRepository().clearActiveUser();
  });

  testWidgets(
      'LoginScreen renders Google.png asset with BoxFit.contain and correct size (20x20)',
      (WidgetTester tester) async {
    final controller = LoginController();

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/google.png',
    );

    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.width, 20);
    expect(imageWidget.height, 20);
    expect(imageWidget.fit, BoxFit.contain);
  });

  testWidgets(
      'AccountSettingsScreen (offline) renders Google.png in Sign-In button with BoxFit.contain and 18x18 size',
      (WidgetTester tester) async {
    await SessionManager().saveSession(
      userId: 'usr_local_test',
      sessionType: SessionType.offline,
    );

    final userRepo = UserRepository();
    await userRepo.saveUser(CurrentUser(
      id: 'usr_local_test',
      displayName: 'Offline User',
      email: 'offline@local.quicknotes',
      sessionType: SessionType.offline,
      isOffline: true,
      createdAt: DateTime.now(),
    ));

    final controller = AccountController(
      sessionManager: SessionManager(),
      userRepository: userRepo,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(420, 900)),
          child: AccountSettingsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/google.png',
    );

    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.width, 18);
    expect(imageWidget.height, 18);
    expect(imageWidget.fit, BoxFit.contain);
  });

  testWidgets(
      'AccountSettingsScreen (authenticated) renders Google.png in Connected badge with BoxFit.contain and 12x12 size',
      (WidgetTester tester) async {
    await SessionManager().saveSession(
      userId: 'usr_google_123',
      sessionType: SessionType.google,
    );

    final userRepo = UserRepository();
    await userRepo.saveUser(CurrentUser(
      id: 'usr_google_123',
      displayName: 'Jane Doe',
      email: 'janedoe@gmail.com',
      photoUrl: null,
      sessionType: SessionType.google,
      isOffline: false,
      createdAt: DateTime.now(),
    ));

    final controller = AccountController(
      sessionManager: SessionManager(),
      userRepository: userRepo,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(420, 900)),
          child: AccountSettingsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/google.png',
    );

    expect(imageFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.width, 12);
    expect(imageWidget.height, 12);
    expect(imageWidget.fit, BoxFit.contain);
  });
}
