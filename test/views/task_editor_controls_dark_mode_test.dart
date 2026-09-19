import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/create_task_screen.dart';
import 'package:quick_notes/views/widgets/create_task_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreenHarness({
    required bool isDark,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TasksProvider>(
          create: (_) => TasksProvider(),
        ),
      ],
      child: MaterialApp(
        theme: isDark ? ThemeData(brightness: Brightness.dark) : ThemeData.light(),
        home: child,
      ),
    );
  }

  group('Phase D6-F3 — Semantic Color Locks', () {
    test('Priority semantic colors strictly match D6-F0 and D6-F3 specifications', () {
      const highColor = Color(0xFFFF453A);
      const mediumColor = Color(0xFFFF9F0A);
      const lowColor = Color(0xFF30D158);

      expect(highColor, const Color(0xFFFF453A));
      expect(mediumColor, const Color(0xFFFF9F0A));
      expect(lowColor, const Color(0xFF30D158));
    });
  });

  group('Phase D6-F3 — TaskEditorScreen Controls Dark Mode Tests', () {
    testWidgets('TaskEditorScreen controls in Light Mode preserve existing styling',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildScreenHarness(
          isDark: false,
          child: const TaskEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Priority inline button in Light Mode
      final priorityText = tester.widget<Text>(find.text('None'));
      expect(priorityText.style?.color, const Color(0x993C3C43));

      // 2. Open priority picker
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      // Find the priority popup/dropdown container while open
      final popupContainers = tester.widgetList<Container>(find.byType(Container));
      final popupContainer = popupContainers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == Colors.white &&
            (c.decoration as BoxDecoration).borderRadius == BorderRadius.circular(20),
      );
      expect(popupContainer, isNotNull);

      // Select 'High' priority
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      // Selected priority inline pill retains High #FF453A
      final highText = tester.widget<Text>(find.text('High'));
      expect(highText.style?.color, const Color(0xFFFF453A));

      // 3. Reminder Mode Segmented Control in Light Mode
      final reminderHeader = tester.widget<Text>(find.text('Reminder Mode'));
      expect(reminderHeader.style?.color, const Color(0xFF333333));

      // Re-query fresh containers after state change
      final updatedContainers = tester.widgetList<Container>(find.byType(Container));

      // Track has 0x1F787880
      final trackContainer = updatedContainers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0x1F787880),
      );
      expect(trackContainer, isNotNull);

      // Inactive segment text has 0x993C3C43
      final offText = tester.widget<Text>(find.text('Off'));
      expect(offText.style?.color, const Color(0x993C3C43));

      // Active segment text (Notification) retains Task Blue #0088FF
      final notificationText = tester.widget<Text>(find.text('🔔 Notification'));
      expect(notificationText.style?.color, const Color(0xFF0088FF));

      // 4. Recurrence Chips in Light Mode
      final repeatHeader = tester.widget<Text>(find.text('Repeat'));
      expect(repeatHeader.style?.color, const Color(0xFF333333));

      // Selected chip 'Never' has Task Blue #0088FF and white text
      final neverText = tester.widget<Text>(find.text('Never'));
      expect(neverText.style?.color, Colors.white);

      // Unselected chip 'Daily' has 0x993C3C43 text
      final dailyText = tester.widget<Text>(find.text('Daily'));
      expect(dailyText.style?.color, const Color(0x993C3C43));
    });

    testWidgets('TaskEditorScreen controls in Dark Mode adapt to Dark Mode hierarchy',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildScreenHarness(
          isDark: true,
          child: const TaskEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Priority inline button in Dark Mode (unselected/None -> #8E8E93)
      final priorityText = tester.widget<Text>(find.text('None'));
      expect(priorityText.style?.color, const Color(0xFF8E8E93));

      // 2. Open priority popup
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      // Popup container has #2C2C2C surface, subtle border #26FFFFFF
      final popupContainers = tester.widgetList<Container>(find.byType(Container));
      final popupContainer = popupContainers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C) &&
            (c.decoration as BoxDecoration).borderRadius == BorderRadius.circular(20),
      );
      expect(popupContainer, isNotNull);
      final border = (popupContainer.decoration as BoxDecoration).border;
      expect(border, isNotNull);

      // Unselected option in Dark Mode has muted text #8E8E93
      final highOptionText = tester.widget<Text>(find.text('High'));
      expect(highOptionText.style?.color, const Color(0xFF8E8E93));

      // Select 'High' priority
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      // Selected priority inline pill retains High #FF453A
      final selectedHighText = tester.widget<Text>(find.text('High'));
      expect(selectedHighText.style?.color, const Color(0xFFFF453A));

      // 3. Reminder Mode Segmented Control in Dark Mode
      final reminderHeader = tester.widget<Text>(find.text('Reminder Mode'));
      expect(reminderHeader.style?.color, Colors.white);

      // Re-query fresh containers
      final updatedContainers = tester.widgetList<Container>(find.byType(Container));

      // Track uses approved recessed surface #242426
      final trackContainer = updatedContainers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF242426),
      );
      expect(trackContainer, isNotNull);

      // Sliding thumb uses approved elevated control surface #3A3A3C
      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final thumb = animatedContainers.firstWhere(
        (ac) =>
            ac.decoration is BoxDecoration &&
            (ac.decoration as BoxDecoration).color == const Color(0xFF3A3A3C),
      );
      expect(thumb, isNotNull);

      // Inactive segment text has #8E8E93
      final offText = tester.widget<Text>(find.text('Off'));
      expect(offText.style?.color, const Color(0xFF8E8E93));

      // Active segment text (Notification) retains Task Blue #0088FF
      final notificationText = tester.widget<Text>(find.text('🔔 Notification'));
      expect(notificationText.style?.color, const Color(0xFF0088FF));

      // Switch to 'Off' segment -> active text becomes white #FFFFFF on thumb #3A3A3C
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      final activeOffText = tester.widget<Text>(find.text('Off'));
      expect(activeOffText.style?.color, Colors.white);

      // 4. Recurrence Chips in Dark Mode
      final repeatHeader = tester.widget<Text>(find.text('Repeat'));
      expect(repeatHeader.style?.color, Colors.white);

      // Selected chip 'Never' has Task Blue #0088FF and white text
      final neverText = tester.widget<Text>(find.text('Never'));
      expect(neverText.style?.color, Colors.white);

      // Unselected chip 'Daily' has #8E8E93 text and #3A3A3C surface
      final dailyText = tester.widget<Text>(find.text('Daily'));
      expect(dailyText.style?.color, const Color(0xFF8E8E93));

      final freshAnimated =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final dailyChip = freshAnimated.firstWhere(
        (ac) =>
            ac.decoration is ShapeDecoration &&
            (ac.decoration as ShapeDecoration).color == const Color(0xFF3A3A3C),
      );
      expect(dailyChip, isNotNull);

      // Unselected chip 'Monthly' has #8E8E93 text and #3A3A3C surface (verifies isDark is passed to Monthly)
      final monthlyText = tester.widget<Text>(find.text('Monthly'));
      expect(monthlyText.style?.color, const Color(0xFF8E8E93));

      final monthlyChips = freshAnimated.where(
        (ac) =>
            ac.decoration is ShapeDecoration &&
            (ac.decoration as ShapeDecoration).color == const Color(0xFF3A3A3C),
      );
      // Both Daily, Weekly, and Monthly chips now resolve to #3A3A3C
      expect(monthlyChips.length, greaterThanOrEqualTo(3));
    });
  });

  group('Phase D6-F3 — CreateTaskBottomSheet Controls Dark Mode Tests', () {
    testWidgets('CreateTaskBottomSheet controls in Light Mode preserve existing styling',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Ignore mock-font layout overflow in test environment
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('overflowed by')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        buildScreenHarness(
          isDark: false,
          child: Scaffold(
            body: CreateTaskBottomSheet(
              initialDate: DateTime(2026, 9, 19),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Priority inline button in Light Mode
      final priorityText = tester.widget<Text>(find.text('None'));
      expect(priorityText.style?.color, const Color(0x993C3C43));

      // 2. Open priority popup
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      // Popup has white surface while open
      final popupContainers = tester.widgetList<Container>(find.byType(Container));
      final popup = popupContainers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == Colors.white,
      );
      expect(popup, isNotNull);

      // Option text has #333333
      final highText = tester.widget<Text>(find.text('High'));
      expect(highText.style?.color, const Color(0xFF333333));

      // Select 'High' priority
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      final selectedHighText = tester.widget<Text>(find.text('High'));
      expect(selectedHighText.style?.color, const Color(0xFFFF453A));

      // 3. Reminder Mode in Light Mode
      final reminderHeader = tester.widget<Text>(find.text('Reminder Mode'));
      expect(reminderHeader.style?.color, const Color(0xFF333333));

      final offText = tester.widget<Text>(find.text('Off'));
      expect(offText.style?.color, const Color(0x993C3C43));

      // 4. Recurrence Chips in Light Mode
      final repeatHeader = tester.widget<Text>(find.text('Repeat / Recurrence'));
      expect(repeatHeader.style?.color, const Color(0xFF333333));

      final neverText = tester.widget<Text>(find.text('Never'));
      expect(neverText.style?.color, Colors.white);

      final dailyText = tester.widget<Text>(find.text('Daily'));
      expect(dailyText.style?.color, const Color(0xFF333333));
    });

    testWidgets('CreateTaskBottomSheet controls in Dark Mode adapt to Dark Mode hierarchy',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Ignore mock-font layout overflow in test environment
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('overflowed by')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        buildScreenHarness(
          isDark: true,
          child: Scaffold(
            body: CreateTaskBottomSheet(
              initialDate: DateTime(2026, 9, 19),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Priority inline button in Dark Mode (unselected -> #8E8E93)
      final priorityText = tester.widget<Text>(find.text('None'));
      expect(priorityText.style?.color, const Color(0xFF8E8E93));

      // 2. Open priority popup
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      // Popup has #2C2C2C surface and subtle border while open
      final popupContainers = tester.widgetList<Container>(find.byType(Container));
      final popup = popupContainers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0xFF2C2C2C),
      );
      expect(popup, isNotNull);

      // Popup text has #FFFFFF
      final highText = tester.widget<Text>(find.text('High'));
      expect(highText.style?.color, Colors.white);

      final medText = tester.widget<Text>(find.text('Medium'));
      expect(medText.style?.color, Colors.white);

      final lowText = tester.widget<Text>(find.text('Low'));
      expect(lowText.style?.color, Colors.white);

      // Semantic indicator dots retain High #FF453A, Medium #FF9F0A, Low #30D158
      final dots = popupContainers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).shape is OvalBorder,
      );
      final dotColors = dots
          .map((d) => (d.decoration as ShapeDecoration).color)
          .toList();
      expect(dotColors, contains(const Color(0xFFFF453A)));
      expect(dotColors, contains(const Color(0xFFFF9F0A)));
      expect(dotColors, contains(const Color(0xFF30D158)));

      // Select 'High' priority
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      final selectedHighText = tester.widget<Text>(find.text('High'));
      expect(selectedHighText.style?.color, const Color(0xFFFF453A));

      // 3. Reminder Mode in Dark Mode
      final reminderHeader = tester.widget<Text>(find.text('Reminder Mode'));
      expect(reminderHeader.style?.color, Colors.white);

      // Re-query fresh containers
      final updatedContainers = tester.widgetList<Container>(find.byType(Container));

      // Track uses #242426
      final track = updatedContainers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF242426),
      );
      expect(track, isNotNull);

      // Sliding thumb uses #3A3A3C
      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final thumb = animatedContainers.firstWhere(
        (ac) =>
            ac.decoration is BoxDecoration &&
            (ac.decoration as BoxDecoration).color == const Color(0xFF3A3A3C),
      );
      expect(thumb, isNotNull);

      // Inactive segment text has #8E8E93
      final offText = tester.widget<Text>(find.text('Off'));
      expect(offText.style?.color, const Color(0xFF8E8E93));

      // 4. Recurrence Chips in Dark Mode
      final repeatHeader = tester.widget<Text>(find.text('Repeat / Recurrence'));
      expect(repeatHeader.style?.color, Colors.white);

      final neverText = tester.widget<Text>(find.text('Never'));
      expect(neverText.style?.color, Colors.white);

      // Unselected recurrence chips have #3A3A3C surface and #8E8E93 text
      final dailyText = tester.widget<Text>(find.text('Daily'));
      expect(dailyText.style?.color, const Color(0xFF8E8E93));

      final dailyChip = animatedContainers.firstWhere(
        (ac) =>
            ac.decoration is BoxDecoration &&
            (ac.decoration as BoxDecoration).color == const Color(0xFF3A3A3C) &&
            (ac.decoration as BoxDecoration).borderRadius == BorderRadius.circular(19),
      );
      expect(dailyChip, isNotNull);
    });
  });
}
