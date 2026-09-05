import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/core/animations/bottom_sheet_transition.dart';
import 'package:quick_notes/core/animations/dialog_transition.dart';
import 'package:quick_notes/core/animations/page_transitions.dart';
import 'package:quick_notes/core/animations/search_transition_routes.dart';
import 'package:quick_notes/core/animations/tactile_card_wrapper.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/views/screens/experimental/sde_drag_test_screen.dart';
import 'package:quick_notes/views/widgets/blurred_bottom_sheet.dart';
import 'package:quick_notes/views/widgets/living_writing_experience.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/services/task_engine.dart';
import 'package:quick_notes/services/reminder_scheduler.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase P4.1 — Global Motion Foundation Tests', () {
    // ── TEST 1: Standard Page Route Tokens ───────────────────────────────────
    test('TEST 1: buildPageRoute consumes QuickNotesMotion tokens and curves', () {
      final route = buildPageRoute<void>(const Scaffold(body: Text('Destination')));

      expect(route, isA<QuickNotesPageRoute<void>>());
      final qRoute = route as QuickNotesPageRoute<void>;

      expect(qRoute.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(qRoute.normalTransitionDuration.inMilliseconds, equals(340));
      expect(qRoute.normalReverseTransitionDuration, equals(QuickNotesMotion.kMotionPageReverse));
      expect(qRoute.normalReverseTransitionDuration.inMilliseconds, equals(260));
    });

    // ── TEST 2: Note Opening Tokens ──────────────────────────────────────────
    test('TEST 2: buildNoteOpeningPageRoute consumes QuickNotesMotion tokens and preserves choreography', () {
      final route = buildNoteOpeningPageRoute<void>(const Scaffold(body: Text('Note Content')));

      expect(route, isA<QuickNotesPageRoute<void>>());
      final qRoute = route as QuickNotesPageRoute<void>;

      expect(qRoute.normalTransitionDuration, equals(QuickNotesMotion.kMotionPage));
      expect(qRoute.normalTransitionDuration.inMilliseconds, equals(340));
      expect(qRoute.normalReverseTransitionDuration, equals(QuickNotesMotion.kMotionPageReverse));
      expect(qRoute.normalReverseTransitionDuration.inMilliseconds, equals(260));
    });

    // ── TEST 3: Reduced Motion Behavioral Override across Custom Routes ─────
    testWidgets('TEST 3A: buildPageRoute respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    buildPageRoute(const Scaffold(body: Text('Pushed Screen'))),
                  );
                },
                child: const Text('Push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push'));
      // Under disableAnimations: true, a single pump should immediately render the pushed destination
      await tester.pump();

      expect(find.text('Pushed Screen'), findsOneWidget);
    });

    testWidgets('TEST 3B: buildNoteOpeningPageRoute respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    buildNoteOpeningPageRoute(const Scaffold(body: Text('Note Screen'))),
                  );
                },
                child: const Text('Open Note'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Note'));
      await tester.pump();

      expect(find.text('Note Screen'), findsOneWidget);
    });

    testWidgets('TEST 3C: PixelAlignedSearchRoute respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    buildSearchTransitionRoute(
                      builder: (context) => const Scaffold(body: Text('Search Screen Content')),
                    ),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search'));
      await tester.pump();

      expect(find.text('Search Screen Content'), findsOneWidget);
    });

    testWidgets('TEST 3D: FabMorphPageRoute respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FabMorphPageRoute(
                      fabBounds: const Rect.fromLTWH(100, 100, 56, 56),
                      builder: (context) => const Scaffold(body: Text('Fab Target')),
                    ),
                  );
                },
                child: const Text('Morph FAB'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Morph FAB'));
      await tester.pump();

      expect(find.text('Fab Target'), findsOneWidget);
    });

    testWidgets('TEST 3E: FolderMorphPageRoute respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FolderMorphPageRoute(
                      cardBounds: const Rect.fromLTWH(50, 50, 120, 80),
                      builder: (context) => const Scaffold(body: Text('Folder Target')),
                    ),
                  );
                },
                child: const Text('Morph Folder'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Morph Folder'));
      await tester.pump();

      expect(find.text('Folder Target'), findsOneWidget);
    });

    testWidgets('TEST 3F: showBlurredBottomSheet respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showBlurredBottomSheet(
                    context: context,
                    child: const Text('Sheet Content'),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();

      expect(find.text('Sheet Content'), findsOneWidget);
    });

    testWidgets('TEST 3G: showAnimatedBottomSheet respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAnimatedBottomSheet(
                    context: context,
                    child: const Text('Animated Sheet Content'),
                  );
                },
                child: const Text('Open Animated Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Animated Sheet'));
      await tester.pump();

      expect(find.text('Animated Sheet Content'), findsOneWidget);
    });

    testWidgets('TEST 3H: showAnimatedDialog respects disableAnimations with immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAnimatedDialog(
                    context: context,
                    child: const Text('Dialog Content'),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      expect(find.text('Dialog Content'), findsOneWidget);
    });

    // ── TEST 4: Normal Motion Preserved ──────────────────────────────────────
    testWidgets('TEST 4: Normal motion animates over full duration when disableAnimations is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    buildPageRoute(const Scaffold(body: Text('Animated Screen'))),
                  );
                },
                child: const Text('Push Normal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push Normal'));
      await tester.pump(); // Start push

      // Advance by half duration (170ms) - route is active and transitioning
      await tester.pump(const Duration(milliseconds: 170));
      expect(find.text('Animated Screen'), findsOneWidget);

      // Advance to full duration (340ms) - route animation completes
      await tester.pump(const Duration(milliseconds: 170));
      expect(find.text('Animated Screen'), findsOneWidget);
    });

    // ── TEST 5: SettingsScreen SDEDragTestScreen Uses Standard Route ─────────
    testWidgets('TEST 5: SettingsScreen SDEDragTestScreen pushes using buildPageRoute (resolves P4-DEF-05)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      final entitlementManager = PremiumEntitlementManager();
      await entitlementManager.initialize();
      await entitlementManager.updateEntitlement(
        PremiumEntitlement.active(productId: premiumLifetimeProductId),
      );

      final settingsProvider = SettingsProvider();
      await settingsProvider.initialize();

      final navObserver = _RouteTypeObserver();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: entitlementManager),
            ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
              update: (_, manager, __) => DefaultFeatureAccess(manager),
            ),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider(create: (_) => NotesProvider()),
            ChangeNotifierProvider(
              create: (_) => TasksProvider(
                engine: TaskEngine(scheduler: LoggingReminderScheduler()),
              ),
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [navObserver],
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to reveal the SDE drag tile
      final tileFinder = find.text('🧪 Test SDE Drag Selection');
      expect(tileFinder, findsOneWidget);
      await tester.ensureVisible(tileFinder);
      await tester.pumpAndSettle();

      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      // Verify the pushed route is a QuickNotesPageRoute rather than a raw MaterialPageRoute
      expect(navObserver.lastPushedRoute, isA<QuickNotesPageRoute>());
      expect(navObserver.lastPushedRoute, isNot(isA<MaterialPageRoute>()));
      expect(find.byType(SDEDragTestScreen), findsOneWidget);
    });

    // ── TEST 6: Hardened QuickNotesMotion Tokens ─────────────────────────────
    test('TEST 6: QuickNotesMotion exposes authoritative modal and curve tokens', () {
      expect(QuickNotesMotion.kMotionSheetPresent, equals(const Duration(milliseconds: 350)));
      expect(QuickNotesMotion.kMotionSheetDismiss, equals(const Duration(milliseconds: 260)));
      expect(QuickNotesMotion.kMotionDialogPresent, equals(const Duration(milliseconds: 240)));
      expect(QuickNotesMotion.kMotionDialogDismiss, equals(const Duration(milliseconds: 180)));
      expect(QuickNotesMotion.kMotionEaseInOutCubic, equals(const Cubic(0.42, 0.0, 0.58, 1.0)));
      expect(QuickNotesMotion.kMotionEaseOutCubic, equals(Curves.easeOutCubic));
      expect(QuickNotesMotion.kMotionEaseInCubic, equals(Curves.easeInCubic));
    });

    // ── TEST 7: Hardened QuickNotesHaptics Semantic Channels ─────────────────
    test('TEST 7: QuickNotesHaptics dispatches all semantic channels safely', () async {
      final List<String> receivedEvents = [];
      QuickNotesHaptics.debugHapticListener = (method) {
        receivedEvents.add(method);
      };

      await QuickNotesHaptics.navigationSelection();
      await QuickNotesHaptics.selection();
      await QuickNotesHaptics.buttonPress();
      await QuickNotesHaptics.subtleSettle();
      await QuickNotesHaptics.destructiveAction();
      await QuickNotesHaptics.errorAlert();
      await QuickNotesHaptics.taskCompletion();
      await QuickNotesHaptics.dragBoundary();

      expect(receivedEvents, equals([
        'navigationSelection',
        'selection',
        'buttonPress',
        'subtleSettle',
        'destructiveAction',
        'errorAlert',
        'taskCompletion',
        'dragBoundary',
      ]));

      QuickNotesHaptics.debugHapticListener = null;
    });

    // ── TEST 8: Hardened TactileCardWrapper Canonical Behavior ────────────────
    testWidgets('TEST 8A: TactileCardWrapper scales to 0.94 and triggers buttonPress haptic', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileCardWrapper(
                onTap: () => tapped = true,
                child: const SizedBox(width: 100, height: 100, child: Text('Card')),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.text('Card');
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90)); // kMotionMicro

      // Should have triggered buttonPress haptic
      expect(haptics, contains('buttonPress'));

      // Verify scale is 0.94
      final ScaleTransition scaleTransition =
          tester.widget(find.byType(ScaleTransition).first);
      expect(scaleTransition.scale.value, closeTo(0.94, 0.01));

      // Release
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 190)); // kMotionRelease
      expect(tapped, isTrue);

      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('TEST 8B: TactileCardWrapper suppresses scaling under reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: TactileCardWrapper(
                onTap: () {},
                child: const SizedBox(width: 100, height: 100, child: Text('Reduced Card')),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.text('Reduced Card');
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      // Under reduced motion, scale must remain exactly 1.0
      final ScaleTransition scaleTransition =
          tester.widget(find.byType(ScaleTransition).first);
      expect(scaleTransition.scale.value, equals(1.0));

      await gesture.up();
      await tester.pump();
    });
  });
}

class _RouteTypeObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is! ModalBottomSheetRoute) {
      lastPushedRoute = route;
    }
  }
}
