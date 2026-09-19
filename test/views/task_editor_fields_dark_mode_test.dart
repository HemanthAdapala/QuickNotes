import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  group('Phase D6-F2 — TaskEditorScreen Fields & Controls Dark Mode Tests', () {
    testWidgets('TaskEditorScreen inputs, labels, and date/time chips in Light Mode',
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

      // 1. Labels in Light Mode
      final titleLabel = tester.widget<Text>(find.text('Task Title'));
      expect(titleLabel.style?.color, const Color(0xFF333333));

      final dueDateLabel = tester.widget<Text>(find.text('Due Date'));
      expect(dueDateLabel.style?.color, const Color(0xFF333333));

      final timeLabel = tester.widget<Text>(find.text('Time'));
      expect(timeLabel.style?.color, const Color(0xFF333333));

      final priorityLabel = tester.widget<Text>(find.text('Priority'));
      expect(priorityLabel.style?.color, const Color(0xFF333333));

      final descLabel =
          tester.widget<Text>(find.text('Task Description (Optional)'));
      expect(descLabel.style?.color, const Color(0xFF333333));

      // 2. Title and Description input text and hint styles
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.length, greaterThanOrEqualTo(2));

      final titleField = textFields[0];
      expect(titleField.style?.color, const Color(0xFF333333));
      expect(titleField.decoration?.hintStyle?.color, const Color(0x993C3C43));

      final descField = textFields[1];
      expect(descField.style?.color, const Color(0xFF333333));
      expect(descField.decoration?.hintStyle?.color, const Color(0x993C3C43));

      // 3. Input container fills in Light Mode (0x28787880)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final inputFills = containers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0x28787880),
      );
      expect(inputFills.length, greaterThanOrEqualTo(4)); // title, date, time, desc
    });

    testWidgets('TaskEditorScreen inputs, labels, and date/time chips in Dark Mode',
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

      // 1. Labels in Dark Mode -> Colors.white
      final titleLabel = tester.widget<Text>(find.text('Task Title'));
      expect(titleLabel.style?.color, Colors.white);

      final dueDateLabel = tester.widget<Text>(find.text('Due Date'));
      expect(dueDateLabel.style?.color, Colors.white);

      final timeLabel = tester.widget<Text>(find.text('Time'));
      expect(timeLabel.style?.color, Colors.white);

      final priorityLabel = tester.widget<Text>(find.text('Priority'));
      expect(priorityLabel.style?.color, Colors.white);

      final descLabel =
          tester.widget<Text>(find.text('Task Description (Optional)'));
      expect(descLabel.style?.color, Colors.white);

      // 2. Title and Description input text and hint styles in Dark Mode
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final titleField = textFields[0];
      expect(titleField.style?.color, Colors.white);
      expect(titleField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));

      final descField = textFields[1];
      expect(descField.style?.color, Colors.white);
      expect(descField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));

      // 3. Input container fills in Dark Mode -> #242426
      final containers = tester.widgetList<Container>(find.byType(Container));
      final inputFills = containers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0xFF242426),
      );
      expect(inputFills.length, greaterThanOrEqualTo(4)); // title, date, time, desc
    });

    testWidgets('TaskEditorScreen Date and Time pickers adapt to Dark Mode theme',
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

      // Tap Due Date chip
      await tester.tap(find.text('Due Date'));
      // Find the TactileButton containing calendar icon and tap it
      final calendarFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            (w.bytesLoader as dynamic).assetName == 'assets/icons/calendar_icon.svg',
      );
      await tester.tap(calendarFinder);
      await tester.pumpAndSettle();

      // Verify DatePickerDialog is displayed with Dark ColorScheme
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final datePickerTheme = Theme.of(tester.element(find.byType(DatePickerDialog)));
      expect(datePickerTheme.colorScheme.brightness, Brightness.dark);
      expect(datePickerTheme.colorScheme.primary, const Color(0xFF0088FF));
      expect(datePickerTheme.colorScheme.surface, const Color(0xFF2C2C2C));
      expect(datePickerTheme.colorScheme.onSurface, Colors.white);

      // Dismiss date picker
      await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('Cancel'),
      ));
      await tester.pumpAndSettle();

      // Tap Time chip
      final clockFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            (w.bytesLoader as dynamic).assetName == 'assets/icons/alarm_clock.svg',
      );
      await tester.tap(clockFinder);
      await tester.pumpAndSettle();

      // Verify TimePickerDialog is displayed with Dark ColorScheme
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final timePickerTheme = Theme.of(tester.element(find.byType(TimePickerDialog)));
      expect(timePickerTheme.colorScheme.brightness, Brightness.dark);
      expect(timePickerTheme.colorScheme.primary, const Color(0xFF0088FF));
      expect(timePickerTheme.colorScheme.surface, const Color(0xFF2C2C2C));
      expect(timePickerTheme.colorScheme.onSurface, Colors.white);

      // Dismiss time picker
      await tester.tap(find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text('Cancel'),
      ));
      await tester.pumpAndSettle();
    });
  });

  group('Phase D6-F2 — CreateTaskBottomSheet Fields & Controls Dark Mode Tests', () {
    testWidgets('CreateTaskBottomSheet inputs and date/time chips in Light Mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // 1. Section labels in Light Mode -> #333333
      final titleLabel = tester.widget<Text>(find.text('Task Title'));
      expect(titleLabel.style?.color, const Color(0xFF333333));

      final dueDateLabel = tester.widget<Text>(find.text('Due Date'));
      expect(dueDateLabel.style?.color, const Color(0xFF333333));

      // 2. Input text and hint in Light Mode
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final titleField = textFields[0];
      expect(titleField.style?.color, const Color(0xFF333333));
      expect(titleField.decoration?.hintStyle?.color, const Color(0x993C3C43));

      // 3. Container fills in Light Mode -> 0x28787880
      final containers = tester.widgetList<Container>(find.byType(Container));
      final inputFills = containers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0x28787880),
      );
      expect(inputFills.length, greaterThanOrEqualTo(4));
    });

    testWidgets('CreateTaskBottomSheet inputs and date/time chips in Dark Mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // 1. Section labels in Dark Mode -> Colors.white
      final titleLabel = tester.widget<Text>(find.text('Task Title'));
      expect(titleLabel.style?.color, Colors.white);

      final dueDateLabel = tester.widget<Text>(find.text('Due Date'));
      expect(dueDateLabel.style?.color, Colors.white);

      // 2. Input text and hint in Dark Mode
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final titleField = textFields[0];
      expect(titleField.style?.color, Colors.white);
      expect(titleField.decoration?.hintStyle?.color, const Color(0xFF8E8E93));

      // 3. Container fills in Dark Mode -> #242426
      final containers = tester.widgetList<Container>(find.byType(Container));
      final inputFills = containers.where(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0xFF242426),
      );
      expect(inputFills.length, greaterThanOrEqualTo(4));
    });
  });
}
