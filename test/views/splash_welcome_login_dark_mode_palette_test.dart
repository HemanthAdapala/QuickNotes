import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/login_controller.dart';
import 'package:quick_notes/controllers/splash_controller.dart';
import 'package:quick_notes/views/screens/login_screen.dart';
import 'package:quick_notes/views/screens/splash_screen.dart';
import 'package:quick_notes/views/screens/welcome_screen.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

/// Test double for [SplashController] that stalls navigation so [SplashScreen]
/// stays mounted during palette assertions.
class _TestSplashController extends SplashController {
  final Completer<SplashDestination> _destinationCompleter =
      Completer<SplashDestination>();

  @override
  Future<SplashDestination> initializeAndDetermineDestination({
    Duration minDisplayDuration = const Duration(milliseconds: 1500),
  }) async {
    return _destinationCompleter.future;
  }
}

/// Test double for [LoginController] enabling inspection of loading spinners.
class _TestLoginController extends LoginController {
  LoginUiState _customState = LoginUiState.idle;

  @override
  LoginUiState get state => _customState;

  void setTestState(LoginUiState newState) {
    _customState = newState;
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
      final Uint8List list = message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes);
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

  Widget buildThemedApp({required Widget child, required bool isDark}) {
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: child,
    );
  }

  group('DM-F4 — Splash Screen Dark Mode Palette Tests', () {
    testWidgets('Splash Screen — Dark Mode Contract', (tester) async {
      final splashController = _TestSplashController();

      await tester.pumpWidget(
        buildThemedApp(
          isDark: true,
          child: SplashScreen(splashController: splashController),
        ),
      );
      await tester.pump();

      // 1. Canvas #1E1E1E
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));

      // 2. Title Colors.white
      final title = tester.widget<Text>(find.text('Quick\nNotes'));
      expect(title.style?.color, Colors.white);

      // 3. System UI: statusBarIconBrightness Brightness.light, statusBarBrightness Brightness.dark
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(overlay.value.statusBarBrightness, Brightness.dark);
    });

    testWidgets('Splash Screen — Light Mode Preservation', (tester) async {
      final splashController = _TestSplashController();

      await tester.pumpWidget(
        buildThemedApp(
          isDark: false,
          child: SplashScreen(splashController: splashController),
        ),
      );
      await tester.pump();

      // 1. Canvas #FFFFFF
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      // 2. Title #333333
      final title = tester.widget<Text>(find.text('Quick\nNotes'));
      expect(title.style?.color, const Color(0xFF333333));

      // 3. System UI: statusBarIconBrightness Brightness.dark, statusBarBrightness Brightness.light
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.dark);
      expect(overlay.value.statusBarBrightness, Brightness.light);
    });
  });

  group('DM-F4 — Welcome Screen Dark Mode Palette Tests', () {
    testWidgets('Welcome Screen — Dark Mode Contract', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          isDark: true,
          child: const WelcomeScreen(),
        ),
      );
      await tester.pump();

      // 1. Canvas #1E1E1E
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));

      // 2. Title Colors.white
      final title = tester.widget<Text>(find.text('Quick\nNotes'));
      expect(title.style?.color, Colors.white);

      // 3. Subtitle #8E8E93
      final subtitle = tester.widget<Text>(
        find.text('Capture thoughts. Organize effortlessly.'),
      );
      expect(subtitle.style?.color, const Color(0xFF8E8E93));

      // 4. Start Button: background Colors.white, border Colors.white
      final startContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = startContainer.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      final border = decoration.border as Border;
      expect(border.top.color, Colors.white);

      // 5. Start text #1C1C1E
      final startText = tester.widget<Text>(find.text('Start'));
      expect(startText.style?.color, const Color(0xFF1C1C1E));

      // 6. Start icon #1C1C1E
      final startIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(startIcon.color, const Color(0xFF1C1C1E));

      // 7. System UI: statusBarIconBrightness Brightness.light, statusBarBrightness Brightness.dark
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(overlay.value.statusBarBrightness, Brightness.dark);
    });

    testWidgets('Welcome Screen — Light Mode Preservation', (tester) async {
      await tester.pumpWidget(
        buildThemedApp(
          isDark: false,
          child: const WelcomeScreen(),
        ),
      );
      await tester.pump();

      // 1. Canvas #FFFDF9
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFDF9));

      // 2. Title #333333
      final title = tester.widget<Text>(find.text('Quick\nNotes'));
      expect(title.style?.color, const Color(0xFF333333));

      // 3. Subtitle 0x99333333
      final subtitle = tester.widget<Text>(
        find.text('Capture thoughts. Organize effortlessly.'),
      );
      expect(subtitle.style?.color, const Color(0x99333333));

      // 4. Start Button: background Colors.white, border #E2E2DF
      final startContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = startContainer.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0xFFE2E2DF));

      // 5. Start text #333333
      final startText = tester.widget<Text>(find.text('Start'));
      expect(startText.style?.color, const Color(0xFF333333));

      // 6. Start icon #333333
      final startIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward_rounded),
      );
      expect(startIcon.color, const Color(0xFF333333));

      // 7. System UI: statusBarIconBrightness Brightness.dark, statusBarBrightness Brightness.light
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.dark);
      expect(overlay.value.statusBarBrightness, Brightness.light);
    });
  });

  group('DM-F4 — Login Screen Dark Mode Palette Tests', () {
    testWidgets('Login Screen — Dark Mode Contract', (tester) async {
      final loginController = _TestLoginController();

      await tester.pumpWidget(
        buildThemedApp(
          isDark: true,
          child: LoginScreen(controller: loginController),
        ),
      );
      await tester.pump();

      // 1. Root ColoredBox canvas #1E1E1E
      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(coloredBox.color, const Color(0xFF1E1E1E));

      // 2. Title Colors.white
      final title = tester.widget<Text>(find.text('Welcome to\nQuick Notes'));
      expect(title.style?.color, Colors.white);

      // 3. Subtitle #8E8E93
      final subtitle = tester.widget<Text>(
        find.text('Sign in to sync your notes across devices, or continue offline on this device.'),
      );
      expect(subtitle.style?.color, const Color(0xFF8E8E93));

      // 4. Google button: background Colors.white, foreground #1C1C1E
      final googleButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(googleButton.style?.backgroundColor?.resolve({}), Colors.white);
      expect(googleButton.style?.foregroundColor?.resolve({}), const Color(0xFF1C1C1E));
      final googleText = tester.widget<Text>(find.text('Continue with Google'));
      expect(googleText.style?.color, const Color(0xFF1C1C1E));

      // 5. Offline button: background #38383A, border #38383A, text Colors.white
      final offlineContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Continue Offline'),
          matching: find.byType(Container),
        ).first,
      );
      final offlineDecoration = offlineContainer.decoration as BoxDecoration;
      expect(offlineDecoration.color, const Color(0xFF38383A));
      final offlineBorder = offlineDecoration.border as Border;
      expect(offlineBorder.top.color, const Color(0xFF38383A));
      final offlineText = tester.widget<Text>(find.text('Continue Offline'));
      expect(offlineText.style?.color, Colors.white);

      // 6. Back button: background #38383A, border #38383A, icon Colors.white
      final backContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
      );
      final backDecoration = backContainer.decoration as BoxDecoration;
      expect(backDecoration.color, const Color(0xFF38383A));
      final backBorder = backDecoration.border as Border;
      expect(backBorder.top.color, const Color(0xFF38383A));

      final backSvg = tester.widget<SvgPicture>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(
        backSvg.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );

      // 7. Footer #8E8E93
      final footer = tester.widget<Text>(
        find.text('By continuing, you agree to our Terms of Service and Privacy Policy.'),
      );
      expect(footer.style?.color, const Color(0xFF8E8E93));

      // 8. System UI: statusBarIconBrightness Brightness.light, statusBarBrightness Brightness.dark
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(overlay.value.statusBarBrightness, Brightness.dark);
    });

    testWidgets('Login Screen — Light Mode Preservation', (tester) async {
      final loginController = _TestLoginController();

      await tester.pumpWidget(
        buildThemedApp(
          isDark: false,
          child: LoginScreen(controller: loginController),
        ),
      );
      await tester.pump();

      // 1. Root ColoredBox canvas #FFFDF9
      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(coloredBox.color, const Color(0xFFFFFDF9));

      // 2. Title #1E1E1E
      final title = tester.widget<Text>(find.text('Welcome to\nQuick Notes'));
      expect(title.style?.color, const Color(0xFF1E1E1E));

      // 3. Subtitle #757575
      final subtitle = tester.widget<Text>(
        find.text('Sign in to sync your notes across devices, or continue offline on this device.'),
      );
      expect(subtitle.style?.color, const Color(0xFF757575));

      // 4. Google button: background #1E1E1E, foreground Colors.white
      final googleButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(googleButton.style?.backgroundColor?.resolve({}), const Color(0xFF1E1E1E));
      expect(googleButton.style?.foregroundColor?.resolve({}), Colors.white);
      final googleText = tester.widget<Text>(find.text('Continue with Google'));
      expect(googleText.style?.color, Colors.white);

      // 5. Offline button: background Colors.white, border #E2E2DF, text #333333
      final offlineContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Continue Offline'),
          matching: find.byType(Container),
        ).first,
      );
      final offlineDecoration = offlineContainer.decoration as BoxDecoration;
      expect(offlineDecoration.color, Colors.white);
      final offlineBorder = offlineDecoration.border as Border;
      expect(offlineBorder.top.color, const Color(0xFFE2E2DF));
      final offlineText = tester.widget<Text>(find.text('Continue Offline'));
      expect(offlineText.style?.color, const Color(0xFF333333));

      // 6. Back button: background Colors.white, border #E2E2DF, icon #333333
      final backContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
      );
      final backDecoration = backContainer.decoration as BoxDecoration;
      expect(backDecoration.color, Colors.white);
      final backBorder = backDecoration.border as Border;
      expect(backBorder.top.color, const Color(0xFFE2E2DF));

      final backSvg = tester.widget<SvgPicture>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(
        backSvg.colorFilter,
        const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
      );

      // 7. Footer #9E9E9E
      final footer = tester.widget<Text>(
        find.text('By continuing, you agree to our Terms of Service and Privacy Policy.'),
      );
      expect(footer.style?.color, const Color(0xFF9E9E9E));

      // 8. System UI: statusBarIconBrightness Brightness.dark, statusBarBrightness Brightness.light
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.dark);
      expect(overlay.value.statusBarBrightness, Brightness.light);
    });

    testWidgets('Login Screen — Google Authentication Loading Spinner Dark Mode', (tester) async {
      final loginController = _TestLoginController();
      loginController.setTestState(LoginUiState.authenticatingGoogle);

      await tester.pumpWidget(
        buildThemedApp(
          isDark: true,
          child: LoginScreen(controller: loginController),
        ),
      );
      await tester.pump();

      // Find spinner inside Google ElevatedButton
      final googleSpinner = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      final spinnerColor =
          (googleSpinner.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(spinnerColor, const Color(0xFF1C1C1E));
    });

    testWidgets('Login Screen — Offline Initialization Loading Spinner Dark Mode', (tester) async {
      final loginController = _TestLoginController();
      loginController.setTestState(LoginUiState.initializingOffline);

      await tester.pumpWidget(
        buildThemedApp(
          isDark: true,
          child: LoginScreen(controller: loginController),
        ),
      );
      await tester.pump();

      // Find spinner inside Offline button container
      final offlineSpinner = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(TactileButton),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      final spinnerColor =
          (offlineSpinner.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(spinnerColor, Colors.white);
    });
  });
}
