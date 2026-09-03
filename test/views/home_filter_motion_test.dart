import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/widgets/filter_pill.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestPill({
    required String filter,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    Color dotColor = const Color(0xFFFFCC00),
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: FilterPill(
              key: ValueKey('filter_pill_$filter'),
              filter: filter,
              text: text,
              isSelected: isSelected,
              dotColor: dotColor,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTestableHomeScreen({
    bool initialShowTasks = true,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: disableAnimations,
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
          Provider<FeatureAccess>(
            create: (c) => DefaultFeatureAccess(
              Provider.of<PremiumEntitlementManager>(c, listen: false),
            ),
          ),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
          ChangeNotifierProvider(create: (_) => TasksProvider()),
        ],
        child: MaterialApp(
          home: HomeScreen(initialShowTasks: initialShowTasks),
        ),
      ),
    );
  }

  group('TEST GROUP A — GEOMETRY', () {
    testWidgets('FilterPill enforces 40px container, 5px dot, and paint-only transform', (tester) async {
      await tester.pumpWidget(buildTestPill(
        filter: 'Today',
        text: "Today's Notes 3",
        isSelected: true,
        onTap: () {},
      ));

      // 40.0px Pill Container
      final containerFinder = find.descendant(
        of: find.byType(FilterPill),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxHeight == 40.0,
        ),
      );
      expect(containerFinder, findsOneWidget);

      final containerSize = tester.getSize(containerFinder);
      expect(containerSize.height, 40.0);

      // 5.0px Selection Indicator Dot
      final dotFinder = find.descendant(
        of: find.byType(FilterPill),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 5.0 &&
              w.constraints?.maxHeight == 5.0,
        ),
      );
      expect(dotFinder, findsOneWidget);
      final dotSize = tester.getSize(dotFinder);
      expect(dotSize.width, 5.0);
      expect(dotSize.height, 5.0);

      // Layout geometry does not shift during compression
      final initialPillSize = tester.getSize(find.byType(FilterPill));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(FilterPill)));
      await tester.pump(QuickNotesMotion.kMotionMicro);

      final compressingPillSize = tester.getSize(find.byType(FilterPill));
      expect(compressingPillSize, equals(initialPillSize),
          reason: 'Touch-down compression must be paint-only and preserve exact layout bounds');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('HomeScreen Filter Bar enforces 52px height, 24px padding, and 12px spacing', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      // 52.0px Filter Bar Container
      final filterBarFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 52.0 && w.child is ListView,
      );
      expect(filterBarFinder, findsOneWidget);

      // 24.0px horizontal padding on ListView
      final listView = tester.widget<ListView>(find.descendant(
        of: filterBarFinder,
        matching: find.byType(ListView),
      ));
      expect(listView.padding, const EdgeInsets.symmetric(horizontal: 24.0));

      // 12.0px spacing between pills
      final firstPillPadding = tester.widget<Padding>(find.ancestor(
        of: find.byKey(const ValueKey('filter_pill_All')),
        matching: find.byType(Padding),
      ).first);
      expect(firstPillPadding.padding, const EdgeInsets.only(right: 12.0));
    });
  });

  group('TEST GROUP B — HAPTICS', () {
    late List<String> hapticLog;

    setUp(() {
      hapticLog = [];
      QuickNotesHaptics.debugHapticListener = (method) {
        hapticLog.add(method);
      };
    });

    tearDown(() {
      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('Tapping inactive filter fires exactly ONE QuickNotesHaptics.selection()', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap 'Weekly' (inactive filter)
      await tester.tap(find.byKey(const ValueKey('filter_pill_Weekly')));
      await tester.pumpAndSettle();

      expect(hapticLog, equals(['selection']),
          reason: 'Switching filter must trigger exactly ONE selection haptic');
    });

    testWidgets('Tapping active filter (sort toggle) fires exactly ONE semantic haptic', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap 'Today' which is the currently active filter
      await tester.tap(find.byKey(const ValueKey('filter_pill_Today')));
      await tester.pumpAndSettle();

      expect(hapticLog, equals(['selection']),
          reason: 'Toggling sort order on active filter must trigger exactly ONE selection haptic');
    });

    testWidgets('No haptic fires on pointer down, pointer cancel, or gesture release without tap', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Touch-down
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('filter_pill_Weekly'))));
      await tester.pump(QuickNotesMotion.kMotionMicro);

      expect(hapticLog, isEmpty, reason: 'onTapDown must not fire haptic feedback');

      // Cancel gesture
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(hapticLog, isEmpty, reason: 'onTapCancel must not fire haptic feedback');
    });
  });

  group('TEST GROUP C — TOUCH COMPRESSION', () {
    testWidgets('FilterPill compresses to ~0.960 on tap down and returns to 1.000 on release', (tester) async {
      await tester.pumpWidget(buildTestPill(
        filter: 'Today',
        text: "Today's Notes 3",
        isSelected: false,
        onTap: () {},
      ));

      await tester.pumpAndSettle();

      final state = tester.state<FilterPillState>(find.byType(FilterPill));
      expect(state.scaleAnimation.value, closeTo(1.000, 0.001));

      // Pointer down
      final gesture = await tester.startGesture(tester.getCenter(find.text("Today's Notes 3")));
      await tester.pump(const Duration(milliseconds: 100)); // Tap down timeout
      await tester.pump(QuickNotesMotion.kMotionMicro);

      // Compressed state: scale ≈ 0.960
      expect(state.scaleAnimation.value, closeTo(0.960, 0.005));

      // Pointer up
      await gesture.up();
      await tester.pump();
      await tester.pump(QuickNotesMotion.kMotionRelease);

      // Released state: returns to 1.000
      expect(state.scaleAnimation.value, closeTo(1.000, 0.001));
    });
  });

  group('TEST GROUP D — SCROLL CANCELLATION', () {
    testWidgets('Horizontal ListView scroll cancels compression and does not switch filter', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      final activeBefore = find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Today')),
        matching: find.byType(AnimatedScale),
      );
      final scaleWidgetBefore = tester.widget<AnimatedScale>(activeBefore);
      expect(scaleWidgetBefore.scale, 1.0, reason: 'Today starts selected');

      // Touch 'Weekly' and drag horizontally to scroll the ListView
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('filter_pill_Weekly'))));
      await tester.pump(const Duration(milliseconds: 30));

      // Drag horizontally beyond touch slop (e.g. 50px left)
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Today must remain the selected filter!
      final scaleWidgetAfter = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Today')),
        matching: find.byType(AnimatedScale),
      ));
      expect(scaleWidgetAfter.scale, 1.0, reason: 'Scroll gesture must cancel tap without changing filter');

      // Weekly must NOT be selected
      final weeklyScale = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Weekly')),
        matching: find.byType(AnimatedScale),
      ));
      expect(weeklyScale.scale, 0.0);
    });
  });

  group('TEST GROUP E — REDUCED MOTION', () {
    testWidgets('Under disableAnimations: true, scale remains 1.000 and dot duration is zero', (tester) async {
      await tester.pumpWidget(buildTestPill(
        filter: 'Today',
        text: "Today's Notes 3",
        isSelected: false,
        disableAnimations: true,
        onTap: () {},
      ));
      await tester.pumpAndSettle();

      Transform getTransform() => tester.widget<Transform>(find.descendant(
        of: find.byType(FilterPill),
        matching: find.byType(Transform),
      ).first);

      // Scale locked at 1.000
      expect(getTransform().transform.getMaxScaleOnAxis(), 1.000);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(FilterPill)));
      await tester.pump(const Duration(milliseconds: 100)); // Tap down press timeout
      await tester.pump(QuickNotesMotion.kMotionMicro);

      // Scale STILL locked at 1.000 despite touch down!
      expect(getTransform().transform.getMaxScaleOnAxis(), 1.000,
          reason: 'Under disableAnimations: true, micro-compression must be locked at 1.000');

      await gesture.up();
      await tester.pumpAndSettle();

      // Dot animation duration is Duration.zero
      final dotAnimatedScale = tester.widget<AnimatedScale>(find.descendant(
        of: find.byType(FilterPill),
        matching: find.byType(AnimatedScale),
      ));
      expect(dotAnimatedScale.duration, Duration.zero,
          reason: 'Under disableAnimations: true, dot transition duration must be Duration.zero');
    });
  });

  group('TEST GROUP F — SORT INTERACTION', () {
    testWidgets('Tapping active filter toggles sort order without moving indicator dot', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      // Today is active
      final todayDotBefore = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Today')),
        matching: find.byType(AnimatedScale),
      ));
      expect(todayDotBefore.scale, 1.0);

      // Tap Today to toggle sort order
      await tester.tap(find.byKey(const ValueKey('filter_pill_Today')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar displayed
      expect(find.text('Sorted: Oldest to Newest'), findsOneWidget);

      // Indicator dot remains on Today!
      final todayDotAfter = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Today')),
        matching: find.byType(AnimatedScale),
      ));
      expect(todayDotAfter.scale, 1.0, reason: 'Sort toggle must keep active indicator on the selected pill');

      await tester.pumpAndSettle();
    });
  });

  group('TEST GROUP G — RAPID INTERACTION', () {
    testWidgets('Rapidly switching filters completes without assertion crashes or stuck scale', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      // Rapid sequence: Weekly -> Monthly -> All -> Today
      await tester.tap(find.byKey(const ValueKey('filter_pill_Weekly')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('filter_pill_Monthly')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('filter_pill_All')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('filter_pill_Today')));
      await tester.pumpAndSettle();

      // Today should be active at the end
      final todayDot = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Today')),
        matching: find.byType(AnimatedScale),
      ));
      expect(todayDot.scale, 1.0);

      // Monthly should be inactive
      final monthlyDot = tester.widget<AnimatedScale>(find.descendant(
        of: find.byKey(const ValueKey('filter_pill_Monthly')),
        matching: find.byType(AnimatedScale),
      ));
      expect(monthlyDot.scale, 0.0);

      // All transforms restored to 1.000
      for (final pill in tester.widgetList<Transform>(find.descendant(
        of: find.byType(FilterPill),
        matching: find.byType(Transform),
      ))) {
        expect(pill.transform.getMaxScaleOnAxis(), closeTo(1.000, 0.001));
      }
    });
  });

  group('TEST GROUP H — ELEMENT IDENTITY', () {
    testWidgets('Filter pills use stable ValueKeys derived from filter name', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen(initialShowTasks: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('filter_pill_All')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_pill_Missed')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_pill_Today')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_pill_Weekly')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_pill_Monthly')), findsOneWidget);
    });
  });
}
