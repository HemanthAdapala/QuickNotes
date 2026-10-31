import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FAB Icon Color Correction — Pure White (#FFFFFF) Invariance Tests', () {
    testWidgets('1. Home + Notes: pencil icon uses Colors.white in both light and dark modes',
        (WidgetTester tester) async {
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                selectedIndex: 0,
                isNotesActive: true,
                isDark: isDark,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pencilFinder = find.byKey(const ValueKey('pencil_icon'));
        expect(pencilFinder, findsOneWidget);

        final SvgPicture svgWidget = tester.widget<SvgPicture>(pencilFinder);
        final ColorFilter? colorFilter = svgWidget.colorFilter;
        expect(
          colorFilter,
          equals(const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          reason: 'Pencil icon must use Colors.white in isDark=$isDark',
        );
      }
    });

    testWidgets('2. Home + Tasks: checklist icon uses Colors.white in both light and dark modes',
        (WidgetTester tester) async {
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                selectedIndex: 0,
                isNotesActive: false,
                isDark: isDark,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checklistFinder = find.byKey(const ValueKey('checklist_icon'));
        expect(checklistFinder, findsOneWidget);

        final Icon iconWidget = tester.widget<Icon>(checklistFinder);
        expect(
          iconWidget.color,
          equals(Colors.white),
          reason: 'Checklist icon must use Colors.white in isDark=$isDark',
        );
      }
    });

    testWidgets('3. Folders: plus icon uses Colors.white in both light and dark modes',
        (WidgetTester tester) async {
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                selectedIndex: 1,
                isDark: isDark,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final plusFinder = find.byKey(const ValueKey('plus_icon'));
        expect(plusFinder, findsOneWidget);

        final Icon iconWidget = tester.widget<Icon>(plusFinder);
        expect(
          iconWidget.color,
          equals(Colors.white),
          reason: 'Plus icon must use Colors.white in isDark=$isDark',
        );
      }
    });

    testWidgets('4. Calendar: pencil icon uses Colors.white in both light and dark modes',
        (WidgetTester tester) async {
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                selectedIndex: 2,
                isDark: isDark,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pencilFinder = find.byKey(const ValueKey('pencil_icon'));
        expect(pencilFinder, findsOneWidget);

        final SvgPicture svgWidget = tester.widget<SvgPicture>(pencilFinder);
        final ColorFilter? colorFilter = svgWidget.colorFilter;
        expect(
          colorFilter,
          equals(const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          reason: 'Calendar pencil icon must use Colors.white in isDark=$isDark',
        );
      }
    });

    testWidgets('5. Settings: FAB remains hidden in both light and dark modes',
        (WidgetTester tester) async {
      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              bottomNavigationBar: QuickNotesLiquidGlassTabBar(
                selectedIndex: 3,
                isDark: isDark,
                onDestinationSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final visibilityFinder = find.byKey(const ValueKey('fab_visibility'));
        expect(visibilityFinder, findsOneWidget);

        final Visibility visibility = tester.widget<Visibility>(visibilityFinder);
        expect(visibility.visible, isFalse);
      }
    });
  });
}

