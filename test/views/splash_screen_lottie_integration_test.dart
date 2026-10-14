import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/controllers/splash_controller.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/deep_link_coordinator.dart';
import 'package:quick_notes/services/splash_animation_resolver.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/login_screen.dart';
import 'package:quick_notes/views/screens/splash_screen.dart';

class _FakeSplashController extends SplashController {
  final Completer<SplashDestination> completer = Completer<SplashDestination>();
  int initializeCalls = 0;

  @override
  Future<SplashDestination> initializeAndDetermineDestination({
    Duration minDisplayDuration = Duration.zero,
  }) async {
    initializeCalls++;
    return completer.future;
  }
}

class _TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> replacedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      replacedRoutes.add(newRoute);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeepLinkCoordinator.instance.consumePendingAction();
  });

  Widget buildTestSplash({
    required SplashController splashController,
    bool isDark = false,
    bool? isNotesTab,
    SettingsProvider? settingsProvider,
    NavigatorObserver? observer,
  }) {
    final settings = settingsProvider ?? SettingsProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        navigatorObservers: observer != null ? [observer] : [],
        home: SplashScreen(
          splashController: splashController,
          isNotesTab: isNotesTab,
        ),
      ),
    );
  }

  group('Phase 3 — Splash Animation Selection & Canvas Tests', () {
    testWidgets('1. Notes + Light Mode resolves to QuickNotesYellowTheme_Light.json and #FFFFFF canvas', (tester) async {
      final controller = _FakeSplashController();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          isNotesTab: true,
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, SplashAnimationResolver.notesLight);
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json');
    });

    testWidgets('2. Tasks + Light Mode resolves to QuickNotes_BlueTheme_Light.json and #FFFFFF canvas', (tester) async {
      final controller = _FakeSplashController();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          isNotesTab: false,
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, SplashAnimationResolver.tasksLight);
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json');
    });

    testWidgets('3. Notes + Dark Mode resolves to QuickNotesYellowTheme_Dark.json and #343434 canvas', (tester) async {
      final controller = _FakeSplashController();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: true,
          isNotesTab: true,
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF343434));

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, SplashAnimationResolver.notesDark);
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotesYellowTheme_Dark.json');
    });

    testWidgets('4. Tasks + Dark Mode resolves to QuickNotes_BlueTheme_Dark.json and #343434 canvas', (tester) async {
      final controller = _FakeSplashController();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: true,
          isNotesTab: false,
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF343434));

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, SplashAnimationResolver.tasksDark);
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotes_BlueTheme_Dark.json');
    });

    testWidgets('5. Saved SettingsProvider preference ("tasks") selects Tasks animation', (tester) async {
      final settings = SettingsProvider();
      await settings.setLastActiveTab('tasks');
      final controller = _FakeSplashController();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          settingsProvider: settings,
        ),
      );
      await tester.pump();

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json');
    });

    testWidgets('6. Saved SettingsProvider preference ("notes") selects Notes animation', (tester) async {
      final settings = SettingsProvider();
      await settings.setLastActiveTab('notes');
      final controller = _FakeSplashController();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          settingsProvider: settings,
        ),
      );
      await tester.pump();

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json');
    });

    testWidgets('7. Explicit startup override (isNotesTab: true) overrides saved "tasks" preference for launch without mutating saved settings', (tester) async {
      final settings = SettingsProvider();
      await settings.setLastActiveTab('tasks');
      final controller = _FakeSplashController();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          isNotesTab: true,
          settingsProvider: settings,
        ),
      );
      await tester.pump();

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotesYellowTheme_Light.json');
      expect(settings.lastActiveTab, 'tasks');
    });

    testWidgets('8. Cold-launch deep link targeting Task overrides saved "notes" tab for splash animation', (tester) async {
      final settings = SettingsProvider();
      await settings.setLastActiveTab('notes');
      DeepLinkCoordinator.instance.setPendingAction(
        const DeepLinkAction(
          DeepLinkActionType.openTask,
          {'taskId': 'task_123'},
        ),
      );
      final controller = _FakeSplashController();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          settingsProvider: settings,
        ),
      );
      await tester.pump();

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      final asset = lottieBuilder.lottie as AssetLottie;
      expect(asset.assetName, 'assets/animations/SplashScreen/QuickNotes_BlueTheme_Light.json');
      expect(settings.lastActiveTab, 'notes');
    });
  });

  group('Phase 3 — Animation and Startup Synchronization Tests', () {
    testWidgets('9. Startup finishes early: waits for full animation before navigating', (tester) async {
      final controller = _FakeSplashController();
      // Startup finishes immediately (at t=0)
      controller.completer.complete(SplashDestination.home);

      final observer = _TestNavigatorObserver();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          observer: observer,
        ),
      );
      await tester.pump();

      // At 500 ms, animation is still playing: must NOT have navigated yet
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(observer.replacedRoutes, isEmpty);

      // At 1417 ms, animation completes: navigation now proceeds
      await tester.pump(const Duration(milliseconds: 917));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(observer.replacedRoutes.length, 1);
    });

    testWidgets('10. Animation finishes early: waits for startup readiness before navigating', (tester) async {
      final controller = _FakeSplashController();
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          observer: observer,
        ),
      );
      await tester.pump();

      // At 1500 ms (> 1417 ms), animation is finished, but startup controller has not completed
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(observer.replacedRoutes, isEmpty);

      // Now startup finishes at t=2000 ms
      controller.completer.complete(SplashDestination.home);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(observer.replacedRoutes.length, 1);
    });

    testWidgets('11. Both conditions are strictly required: neither one alone triggers navigation', (tester) async {
      final controller = _FakeSplashController();
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          observer: observer,
        ),
      );
      await tester.pump();

      // Neither ready
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(observer.replacedRoutes, isEmpty);

      // Startup ready, but animation not ready
      controller.completer.complete(SplashDestination.home);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(observer.replacedRoutes, isEmpty);

      // Let animation finish
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(observer.replacedRoutes.length, 1);
    });

    testWidgets('12. Prevents duplicate navigation and handles multiple status listener triggers safely', (tester) async {
      final controller = _FakeSplashController();
      controller.completer.complete(SplashDestination.home);

      final observer = _TestNavigatorObserver();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          observer: observer,
        ),
      );
      await tester.pump();

      // Let animation finish
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(observer.replacedRoutes.length, 1);

      // Additional frame pumps should not trigger extra navigation
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(observer.replacedRoutes.length, 1);
    });
  });

  group('Phase 4 — Native Layer Blur & Asset Integrity Tests', () {
    testWidgets('13. SplashScreen configures dynamic blur delegates on circle layers to bypass Lottie engine caching bug', (tester) async {
      final controller = _FakeSplashController();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          isDark: false,
          isNotesTab: true,
        ),
      );
      await tester.pump();

      final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(lottieBuilder.delegates, isNotNull,
          reason: 'Runtime delegates are required to bypass lottie:3.5.1 FillContent caching bug on animated frames');
      expect(lottieBuilder.delegates!.values!.length, equals(3),
          reason: 'Delegates must target Small, Medium, and Large circle layers');
    });

    test('14. All four animation variants have native Gaussian Blur (ty: 29) parsed at approximately 350.0 on all circle layers', () async {
      final files = [
        SplashAnimationResolver.notesLight,
        SplashAnimationResolver.notesDark,
        SplashAnimationResolver.tasksLight,
        SplashAnimationResolver.tasksDark,
      ];

      for (final filePath in files) {
        final bytes = await File(filePath).readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        for (final layerName in ['Small', 'Medium', 'Large']) {
          final layer = comp.layers.firstWhere((l) => l.name == layerName);
          expect(layer.blurEffect, isNotNull,
              reason: '$filePath: Layer $layerName must have parsed blurEffect');
          final anim = layer.blurEffect!.blurriness.createAnimation();
          expect(anim.value, closeTo(350.0, 0.01),
              reason: '$filePath: Layer $layerName parsed blur must be ~350.0');
        }
      }
    });

    test('15. Circle layers (Small, Medium, Large) have strictly non-zero blur radius in LottieComposition', () async {
      final files = [
        SplashAnimationResolver.notesLight,
        SplashAnimationResolver.notesDark,
        SplashAnimationResolver.tasksLight,
        SplashAnimationResolver.tasksDark,
      ];

      for (final filePath in files) {
        final bytes = await File(filePath).readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        for (final layerName in ['Small', 'Medium', 'Large']) {
          final layer = comp.layers.firstWhere((l) => l.name == layerName);
          final anim = layer.blurEffect!.blurriness.createAnimation();
          expect(anim.value, isNonZero);
          expect(anim.value, isPositive);
        }
      }
    });

    test('16. Animation timing and geometry preserved across all four variants', () async {
      final files = [
        SplashAnimationResolver.notesLight,
        SplashAnimationResolver.notesDark,
        SplashAnimationResolver.tasksLight,
        SplashAnimationResolver.tasksDark,
      ];

      for (final filePath in files) {
        final bytes = await File(filePath).readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        expect(comp.startFrame, equals(0.0));
        expect(comp.endFrame, closeTo(85.0, 0.05));
        expect(comp.frameRate, equals(60.0));
        expect(comp.bounds.width, equals(402.0));
        expect(comp.bounds.height, equals(874.0));
        expect(comp.duration.inMilliseconds, equals(1416));
      }
    });

    testWidgets('17. Cold start only: The app does not replay the splash animation on background resume', (tester) async {
      final controller = _FakeSplashController();
      controller.completer.complete(SplashDestination.login);

      final observer = _TestNavigatorObserver();
      await tester.pumpWidget(
        buildTestSplash(
          splashController: controller,
          observer: observer,
        ),
      );
      await tester.pump();

      // Let animation complete and navigate to LoginScreen
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(observer.replacedRoutes.length, 1);

      // Simulate app sent to background (paused)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));

      // Simulate app resumed to foreground (resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verify SplashScreen was NOT remounted, replayed, or navigated to
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(observer.replacedRoutes.length, 1);
      expect(observer.pushedRoutes.length, 1); // initial route only
    });

    testWidgets('18. Responsive full-screen splash background adapts edge-to-edge across diverse device aspect ratios without constraining animation', (tester) async {
      final testSizes = [
        const Size(402, 874),   // Baseline composition dimensions
        const Size(1080, 1920), // 16:9 standard phone
        const Size(1080, 2400), // 20:9 modern tall phone
        const Size(1440, 3088), // S23 Ultra physical device
        const Size(1536, 2048), // Tablet 4:3 aspect ratio
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = _FakeSplashController();
        await tester.pumpWidget(
          buildTestSplash(
            splashController: controller,
            isDark: false,
            isNotesTab: true,
          ),
        );
        await tester.pump();

        // 1. Verify Scaffold background color covers canvas
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

        // 2. Verify independent full-screen background layer covers the entire viewport edge-to-edge
        final coloredBox = find.byType(ColoredBox);
        expect(coloredBox, findsWidgets);
        final bgRenderBox = tester.renderObject<RenderBox>(coloredBox.first);
        expect(bgRenderBox.size.width, equals(size.width));
        expect(bgRenderBox.size.height, equals(size.height));

        // 3. Verify Lottie animation preserves BoxFit.contain and original composition geometry
        final lottieBuilder = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
        expect(lottieBuilder.fit, BoxFit.cover);
        expect(lottieBuilder.delegates, isNotNull);
        expect(lottieBuilder.delegates!.values!.length, equals(3));
      }
    });
  });
}
