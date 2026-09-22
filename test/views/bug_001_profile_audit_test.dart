import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quick_notes/models/current_user.dart';
import 'package:quick_notes/models/session_type.dart';
import 'package:quick_notes/repositories/user_repository.dart';
import 'package:quick_notes/services/session_manager.dart';
import 'package:quick_notes/views/screens/account/account_profile_screen.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/grouped_list_container.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    final secureStorageStore = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore[args['key'] as String] = args['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          return secureStorageStore[args['key'] as String];
        } else if (methodCall.method == 'delete') {
          final args = Map<String, dynamic>.from(methodCall.arguments as Map);
          secureStorageStore.remove(args['key'] as String);
          return null;
        }
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget buildTestApp(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Material(child: child),
      ),
    );
  }

  group('BUG-001 TEST A — AccountProfileScreen Header & Initial Frame Stability', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionManager().init();
      await SessionManager().saveSession(
        userId: 'usr_setup_test_1',
        sessionType: SessionType.google,
      );

      final userRepo = UserRepository();
      final now = DateTime.now();
      await userRepo.saveUser(CurrentUser(
        id: 'usr_setup_test_1',
        email: 'testuser@gmail.com',
        displayName: 'Test User',
        sessionType: SessionType.google,
        isOffline: false,
        createdAt: now,
      ));
    });

    testWidgets('AppHeaderBar and Back button mount on frame 0 during loading in setup flow', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const AccountProfileScreen(isSetupFlow: true)),
      );

      // Frame 0: While loading profile data, AppHeaderBar MUST be present immediately
      expect(find.byType(AppHeaderBar), findsOneWidget,
          reason: 'AppHeaderBar must mount on frame 0 to avoid backdrop texture glitch');
      expect(find.byType(TactileButton), findsWidgets);
      expect(find.byType(SvgPicture), findsWidgets,
          reason: 'Back button SVG angle_left must be present on frame 0');

      // Now allow async data loading to finish on real event loop
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // After loading, AppHeaderBar is still present and stable
      expect(find.byType(AppHeaderBar), findsOneWidget);
      expect(find.byType(SvgPicture), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'Loading indicator should dismiss once profile data is loaded');
      expect(find.text('Change Photo'), findsOneWidget,
          reason: 'Profile form content should be rendered');
    });

    testWidgets('Back button tap triggers pop navigation in standard flow without throwing', (tester) async {
      bool didPop = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountProfileScreen(isSetupFlow: false),
                  ),
                );
                didPop = true;
              },
              child: const Text('Open Profile'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AccountProfileScreen), findsOneWidget);
      expect(find.byType(AppHeaderBar), findsOneWidget);

      final backButton = find.descendant(
        of: find.byType(AppHeaderBar),
        matching: find.byType(TactileButton),
      );
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(didPop, isTrue, reason: 'Back button should pop the navigator in standard flow');
      expect(find.byType(AccountProfileScreen), findsNothing);
    });
  });

  group('BUG-001 TEST B — GroupedTile.keyValue Google Connected Layout', () {
    final testWidths = [320.0, 360.0, 390.0, 412.0];

    for (final width in testWidths) {
      testWidgets('Renders "Account" and "Google Connected" on single line at width ${width.toInt()}dp without overflow', (tester) async {
        FlutterErrorDetails? errorCaught;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          errorCaught = details;
        };

        try {
          await tester.pumpWidget(
            buildTestApp(
              Center(
                child: SizedBox(
                  width: width,
                  child: GroupedListContainer(
                    width: width,
                    children: [
                      GroupedTile.keyValue(
                        title: 'Account',
                        value: 'Google Connected',
                      ),
                    ],
                  ),
                ),
              ),
              size: Size(width, 800),
            ),
          );

          expect(errorCaught, isNull, reason: 'No layout error or RenderFlex overflow at ${width}dp');

          final titleFinder = find.text('Account');
          final valueFinder = find.text('Google Connected');

          expect(titleFinder, findsOneWidget);
          expect(valueFinder, findsOneWidget);

          // Verify value is constrained to a single line
          final valueTextWidget = tester.widget<Text>(valueFinder);
          expect(valueTextWidget.maxLines, equals(1));

          // Verify height is consistent with a single line (<= 24dp)
          final valueSize = tester.getSize(valueFinder);
          expect(valueSize.height, lessThanOrEqualTo(24.0),
              reason: 'Value "Google Connected" must fit on a single line');

          // Verify value is aligned flush against the right margin (16dp padding)
          final valueRight = tester.getTopRight(valueFinder).dx;
          final containerRight = tester.getTopRight(find.byType(GroupedListContainer)).dx;
          expect(containerRight - valueRight, closeTo(16.0, 0.5),
              reason: 'Value "Google Connected" must be right-aligned flush against the right padding');
        } finally {
          FlutterError.onError = originalOnError;
        }
      });
    }

    testWidgets('Long title and value layout resilience at 320dp', (tester) async {
      FlutterErrorDetails? errorCaught;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        errorCaught = details;
      };

      try {
        await tester.pumpWidget(
          buildTestApp(
            Center(
              child: SizedBox(
                width: 320.0,
                child: GroupedListContainer(
                  children: [
                    GroupedTile.keyValue(
                      title: 'Database Compression & Storage',
                      value: 'Standard (LZ4 Fast)',
                    ),
                  ],
                ),
              ),
            ),
            size: const Size(320.0, 800),
          ),
        );

        expect(errorCaught, isNull, reason: 'No RenderFlex overflow for long title at 320dp');
        expect(find.text('Database Compression & Storage'), findsOneWidget);
        expect(find.text('Standard (LZ4 Fast)'), findsOneWidget);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });
}
