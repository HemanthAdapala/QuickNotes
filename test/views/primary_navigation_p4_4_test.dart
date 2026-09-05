import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase P4.4 — Primary Navigation & Tab Motion Tests (P4.4-DEF-01)', () {
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

    Widget buildTestWidget({
      required int initialIndex,
      required ValueChanged<int> onDestinationSelected,
      bool disableAnimations = false,
    }) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return AppBottomNavigationBar(
                  selectedIndex: initialIndex,
                  onDestinationSelected: onDestinationSelected,
                );
              },
            ),
          ),
        ),
      );
    }

    // ── REQUIRED TEST 1: Normal-motion inactive-tab selection ──────────────────
    testWidgets(
        'TEST 1: Normal-motion inactive-tab selection changes destination with exactly ONE navigationSelection haptic',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: selectedIndex,
          onDestinationSelected: (i) => selectedIndex = i,
          disableAnimations: false,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap Folders tab (index 1)
      await tester.tap(find.bySemanticsLabel('Folders'));
      await tester.pump();

      expect(selectedIndex, 1,
          reason: 'Selected index should update to 1 for Folders');
      expect(hapticLog, ['navigationSelection'],
          reason:
              'Normal motion inactive tab switch must fire exactly ONE navigationSelection haptic');

      await tester.pumpAndSettle();
    });

    // ── REQUIRED TEST 2: Reduced-motion inactive-tab selection (P4.4-DEF-01) ───
    testWidgets(
        'TEST 2: Reduced-motion inactive-tab selection changes destination immediately with exactly ONE navigationSelection haptic',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: selectedIndex,
          onDestinationSelected: (i) => selectedIndex = i,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Tap Calendar tab (index 2) under reduced motion
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump();

      expect(selectedIndex, 2,
          reason: 'Destination must change immediately under reduced motion');
      expect(hapticLog, ['navigationSelection'],
          reason:
              'Reduced-motion inactive tab switch must fire exactly ONE navigationSelection haptic (resolves P4.4-DEF-01)');

      await tester.pumpAndSettle();
    });

    // ── REQUIRED TEST 3: Normal-motion active-tab re-tap ─────────────────────
    testWidgets(
        'TEST 3: Normal-motion active-tab re-tap preserves destination with ZERO navigationSelection haptics',
        (tester) async {
      int selectedIndex = 1;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: selectedIndex,
          onDestinationSelected: (i) => selectedIndex = i,
          disableAnimations: false,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Re-tap already active Folders tab (index 1)
      await tester.tap(find.bySemanticsLabel('Folders'));
      await tester.pump();

      expect(selectedIndex, 1,
          reason: 'Destination should remain unchanged on re-tap');
      expect(hapticLog, isEmpty,
          reason:
              'Re-tapping currently active tab in normal motion must fire ZERO navigationSelection haptics');

      await tester.pumpAndSettle();
    });

    // ── REQUIRED TEST 4: Reduced-motion active-tab re-tap ────────────────────
    testWidgets(
        'TEST 4: Reduced-motion active-tab re-tap preserves destination with ZERO navigationSelection haptics',
        (tester) async {
      int selectedIndex = 2;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: selectedIndex,
          onDestinationSelected: (i) => selectedIndex = i,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();

      // Re-tap already active Calendar tab (index 2) under reduced motion
      await tester.tap(find.bySemanticsLabel('Calendar'));
      await tester.pump();

      expect(selectedIndex, 2,
          reason: 'Destination should remain unchanged on re-tap');
      expect(hapticLog, isEmpty,
          reason:
              'Re-tapping currently active tab under reduced motion must fire ZERO navigationSelection haptics');

      await tester.pumpAndSettle();
    });

    // ── REQUIRED TEST 5: Reduced-motion indicator visual motion disabled ───────
    testWidgets(
        'TEST 5: Reduced-motion navigation disables liquid stretch and immediately rests at destination geometry',
        (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: selectedIndex,
          onDestinationSelected: (i) => selectedIndex = i,
          disableAnimations: true,
        ),
      );
      await tester.pump();

      final indicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(indicatorFinder, findsOneWidget);
      final initialSize = tester.getSize(indicatorFinder);
      expect(initialSize.width, closeTo(70.0, 0.5));

      // Tap Settings (index 3)
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pump(); // Single frame

      expect(selectedIndex, 3,
          reason: 'Destination must change immediately on frame 1');
      final postTapSize = tester.getSize(indicatorFinder);
      expect(postTapSize.width, closeTo(70.0, 0.5),
          reason:
              'Indicator must immediately rest at 70px with zero liquid stretch under reduced motion');
    });

    // ── REQUIRED TEST 6: Existing FAB haptic behavior remains unchanged ──────
    testWidgets(
        'TEST 6: FAB (index 4) preserves existing haptic behavior identically under normal and reduced motion',
        (tester) async {
      int tappedIndex = -1;

      // 6A: Normal motion FAB tap from tab 0
      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 0,
          onDestinationSelected: (i) => tappedIndex = i,
          disableAnimations: false,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();
      await tester.tap(find.bySemanticsLabel('Create note'));
      await tester.pump();

      expect(tappedIndex, 4);
      final normalHaptic = List<String>.from(hapticLog);
      await tester.pumpAndSettle();

      // 6B: Reduced motion FAB tap from tab 0
      tappedIndex = -1;
      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 0,
          onDestinationSelected: (i) => tappedIndex = i,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();
      await tester.tap(find.bySemanticsLabel('Create note'));
      await tester.pump();

      expect(tappedIndex, 4);
      expect(hapticLog, normalHaptic,
          reason:
              'Reduced-motion FAB tap haptic must identically match normal-motion FAB tap haptic');
      await tester.pumpAndSettle();

      // 6C: When FAB itself is selected (index 4), re-tapping fires buttonPress
      tappedIndex = -1;
      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 4,
          onDestinationSelected: (i) => tappedIndex = i,
          disableAnimations: false,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();
      await tester.tap(find.bySemanticsLabel('Create note'));
      await tester.pump();

      expect(tappedIndex, 4);
      expect(hapticLog, ['buttonPress'],
          reason: 'FAB active re-tap fires buttonPress haptic');
      await tester.pumpAndSettle();

      // 6D: When FAB itself is selected under reduced motion, re-tapping also fires buttonPress
      tappedIndex = -1;
      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 4,
          onDestinationSelected: (i) => tappedIndex = i,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      hapticLog.clear();
      await tester.tap(find.bySemanticsLabel('Create note'));
      await tester.pump();

      expect(tappedIndex, 4);
      expect(hapticLog, ['buttonPress'],
          reason: 'FAB active re-tap under reduced motion also fires buttonPress haptic');
      await tester.pumpAndSettle();
    });
  });
}
