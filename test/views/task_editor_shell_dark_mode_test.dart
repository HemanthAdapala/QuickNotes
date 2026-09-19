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

  group('Phase D6-F1 — TaskEditorScreen Shell Dark Mode Tests', () {
    testWidgets('TaskEditorScreen in Light Mode resolves to light palette and preserved geometry',
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

      // 1. Scaffold background is Colors.white
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);

      // 2. Card background is Colors.white and shadow exists
      final containers = tester.widgetList<Container>(find.byType(Container));
      final cardContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == Colors.white &&
            (c.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.only(
                  topLeft: Radius.circular(30.0),
                  topRight: Radius.circular(30.0),
                ),
      );
      final cardDeco = cardContainer.decoration as BoxDecoration;
      expect(cardDeco.color, Colors.white);

      // Outer card stack container shadow
      final shadowContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).boxShadow != null &&
            (c.decoration as BoxDecoration).boxShadow!.isNotEmpty,
      );
      final shadowDeco = shadowContainer.decoration as BoxDecoration;
      expect(shadowDeco.boxShadow!.first.color,
          const Color(0xFF333333).withValues(alpha: 0.06));

      // 3. AppHeaderBar icon colors are dark (0xFF1C1C1E)
      final backSvg = tester.widget<SvgPicture>(find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.colorFilter ==
                const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
      ));
      expect(backSvg, isNotNull);

      final moreIcon = tester.widget<Icon>(find.byIcon(Icons.more_horiz_rounded));
      expect(moreIcon.color, const Color(0xFF1C1C1E));

      // 4. Cancel button uses light 0x28787880 fill and 0x993C3C43 text
      final cancelText = tester.widget<Text>(find.text('Cancel'));
      expect(cancelText.style?.color, const Color(0x993C3C43));

      // 5. Save button uses #0088FF and white text
      final saveText = tester.widget<Text>(find.text('Save'));
      expect(saveText.style?.color, Colors.white);
    });

    testWidgets('TaskEditorScreen in Dark Mode resolves to #1E1E1E root and #2C2C2C card',
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

      // 1. Scaffold background is #1E1E1E
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));

      // 2. Card background is #2C2C2C
      final containers = tester.widgetList<Container>(find.byType(Container));
      final cardContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C) &&
            (c.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.only(
                  topLeft: Radius.circular(30.0),
                  topRight: Radius.circular(30.0),
                ),
      );
      final cardDeco = cardContainer.decoration as BoxDecoration;
      expect(cardDeco.color, const Color(0xFF2C2C2C));

      // 3. AppHeaderBar icon colors are white in Dark Mode
      final backSvg = tester.widget<SvgPicture>(find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.colorFilter ==
                const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ));
      expect(backSvg, isNotNull);

      final moreIcon = tester.widget<Icon>(find.byIcon(Icons.more_horiz_rounded));
      expect(moreIcon.color, Colors.white);

      // 4. Cancel button uses #3A3A3C fill and white text
      final cancelText = tester.widget<Text>(find.text('Cancel'));
      expect(cancelText.style?.color, Colors.white);

      // 5. Save button uses #0088FF and white text
      final saveText = tester.widget<Text>(find.text('Save'));
      expect(saveText.style?.color, Colors.white);
    });
  });

  group('Phase D6-F1 — CreateTaskBottomSheet Shell Dark Mode Tests', () {
    testWidgets('CreateTaskBottomSheet in Light Mode resolves to light palette',
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

      // 1. Sheet surface is Colors.white
      final containers = tester.widgetList<Container>(find.byType(Container));
      final sheetContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == Colors.white &&
            (c.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
      );
      expect((sheetContainer.decoration as BoxDecoration).color, Colors.white);

      // 2. Handle is 0x4C3C3C43
      final handleContainer = containers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0x4C3C3C43),
      );
      expect((handleContainer.decoration as ShapeDecoration).color,
          const Color(0x4C3C3C43));

      // 3. Close pill button uses 0x19000000 container and 0xFF1C1C1E icon
      final closeContainer = containers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0x19000000),
      );
      expect((closeContainer.decoration as ShapeDecoration).color,
          const Color(0x19000000));

      final closeSvg = tester.widget<SvgPicture>(find.descendant(
        of: find.byWidget(closeContainer),
        matching: find.byType(SvgPicture),
      ));
      expect(
        closeSvg.colorFilter,
        const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
      );
    });

    testWidgets('CreateTaskBottomSheet in Dark Mode resolves to #2C2C2C sheet, #5A5A5A handle, #3A3A3C close',
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

      // 1. Sheet surface is #2C2C2C
      final containers = tester.widgetList<Container>(find.byType(Container));
      final sheetContainer = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xFF2C2C2C) &&
            (c.decoration as BoxDecoration).borderRadius ==
                const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
      );
      expect(
          (sheetContainer.decoration as BoxDecoration).color, const Color(0xFF2C2C2C));

      // 2. Handle is #5A5A5A
      final handleContainer = containers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0xFF5A5A5A),
      );
      expect((handleContainer.decoration as ShapeDecoration).color,
          const Color(0xFF5A5A5A));

      // 3. Close pill button uses #3A3A3C container and Colors.white icon
      final closeContainer = containers.firstWhere(
        (c) =>
            c.decoration is ShapeDecoration &&
            (c.decoration as ShapeDecoration).color == const Color(0xFF3A3A3C),
      );
      expect((closeContainer.decoration as ShapeDecoration).color,
          const Color(0xFF3A3A3C));

      final closeSvg = tester.widget<SvgPicture>(find.descendant(
        of: find.byWidget(closeContainer),
        matching: find.byType(SvgPicture),
      ));
      expect(
        closeSvg.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    });
  });
}
