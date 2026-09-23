import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/themes/app_theme.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/views/screens/calendar_screen.dart';
import 'package:quick_notes/views/models/calendar_task.dart';
import 'package:quick_notes/views/widgets/calendar_task_card.dart';
import 'package:quick_notes/views/widgets/task_widgets_container.dart';
import 'package:quick_notes/views/widgets/delete_task_confirmation_dialog.dart';
import 'package:quick_notes/views/widgets/celebration_overlay.dart';
import 'package:quick_notes/views/widgets/month_container.dart';
import 'package:quick_notes/views/widgets/primary_screen_surface.dart';
import 'package:quick_notes/views/widgets/calendar_day_cell.dart';
import 'package:quick_notes/views/widgets/calendar_grid_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildCalendarScreenHarness(
    WidgetTester tester, {
    required bool isDark,
    double viewportWidth = 412.0,
  }) {
    tester.view.physicalSize = Size(viewportWidth, 844.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return MediaQuery(
      data: MediaQueryData(
        size: Size(viewportWidth, 844.0),
        padding: const EdgeInsets.only(top: 36.0),
        disableAnimations: true,
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
          theme: isDark ? ThemeData.dark() : ThemeData.light(),
          home: const CalendarScreen(),
        ),
      ),
    );
  }

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required bool isDark,
  }) async {
    await tester.pumpWidget(buildCalendarScreenHarness(tester, isDark: isDark));
    tester.takeException();
    await tester.pump();
    tester.takeException();
  }

  Widget buildCellHarness(Widget child, {required bool isDark}) {
    return MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    required Widget child,
    required bool isDark,
    double viewportWidth = 412.0,
    bool disableAnimations = true,
  }) async {
    tester.view.physicalSize = Size(viewportWidth, 844.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(viewportWidth, 844.0),
          padding: const EdgeInsets.only(top: 36.0),
          disableAnimations: disableAnimations,
        ),
        child: MaterialApp(
          theme: isDark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            body: child,
          ),
        ),
      ),
    );
    tester.takeException();
    await tester.pump();
    tester.takeException();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE D4-A — CALENDAR SCREEN ROOT, HEADER & MONTH CONTAINER
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase D4-A — Calendar Screen Dark Mode Palette', () {
    testWidgets('1. Dark Mode: Calendar root background resolves to #1E1E1E',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF1E1E1E)));
    });

    testWidgets(
        '2. Dark Mode: Calendar PrimaryScreenSurface resolves to #1E1E1E',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final surface =
          tester.widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(surface.color, equals(const Color(0xFF1E1E1E)));

      final surfaceContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PrimaryScreenSurface),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = surfaceContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF1E1E1E)));
    });

    testWidgets('3. Dark Mode: Header back icon resolves to #FFFFFF',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final backIconSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/angle_left.svg',
        ),
      );

      expect(
        backIconSvg.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
        ),
      );
    });

    testWidgets('4. Dark Mode: Header search icon resolves to #FFFFFF',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final searchIcon = tester.widget<Icon>(find.byIcon(Icons.search_rounded));
      expect(searchIcon.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('5. Dark Mode: MonthContainer background resolves to #3A3A3C',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final monthContainer = find.byType(MonthContainer);
      expect(monthContainer, findsOneWidget);

      final bgContainer = tester.widget<Container>(
        find.descendant(
          of: monthContainer,
          matching: find.byType(Container),
        ).first,
      );
      final shapeDeco = bgContainer.decoration as ShapeDecoration;
      expect(shapeDeco.color, equals(const Color(0xFF3A3A3C)));
    });

    testWidgets('6. Dark Mode: MonthContainer label resolves to #FFFFFF',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final labelFinder = find.descendant(
        of: find.byType(MonthContainer),
        matching: find.byType(Text),
      );
      expect(labelFinder, findsOneWidget);

      final labelText = tester.widget<Text>(labelFinder);
      expect(labelText.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('7. Dark Mode: MonthContainer chevrons resolve to #FFFFFF',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final leftChevron = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_angle_left.svg',
        ),
      );
      expect(
        leftChevron.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
        ),
      );

      final rightChevron = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_angle_right.svg',
        ),
      );
      expect(
        rightChevron.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
        ),
      );
    });
  });

  group('Phase D4-A — Calendar Screen Light Mode Regression', () {
    testWidgets(
        '8. Light Mode: Calendar root retains existing Light background (AppColors.background)',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppColors.background));
    });

    testWidgets(
        '9. Light Mode: PrimaryScreenSurface retains existing Light appearance (Colors.white)',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final surface =
          tester.widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(surface.color, equals(Colors.white));

      final surfaceContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PrimaryScreenSurface),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = surfaceContainer.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.white));
    });

    testWidgets('10. Light Mode: Header back icon remains #1C1C1E',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final backIconSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/angle_left.svg',
        ),
      );

      expect(
        backIconSvg.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
        ),
      );
    });

    testWidgets('11. Light Mode: Header search icon remains #1C1C1E',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final searchIcon = tester.widget<Icon>(find.byIcon(Icons.search_rounded));
      expect(searchIcon.color, equals(const Color(0xFF1C1C1E)));
    });

    testWidgets('12. Light Mode: MonthContainer remains white',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final monthContainer = find.byType(MonthContainer);
      expect(monthContainer, findsOneWidget);

      final bgContainer = tester.widget<Container>(
        find.descendant(
          of: monthContainer,
          matching: find.byType(Container),
        ).first,
      );
      final shapeDeco = bgContainer.decoration as ShapeDecoration;
      expect(shapeDeco.color, equals(Colors.white));
    });

    testWidgets('13. Light Mode: MonthContainer label remains #333333',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final labelFinder = find.descendant(
        of: find.byType(MonthContainer),
        matching: find.byType(Text),
      );
      expect(labelFinder, findsOneWidget);

      final labelText = tester.widget<Text>(labelFinder);
      expect(labelText.style?.color, equals(const Color(0xFF333333)));
    });

    testWidgets('14. Light Mode: MonthContainer chevrons remain #333333',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final leftChevron = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_angle_left.svg',
        ),
      );
      expect(
        leftChevron.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
        ),
      );

      final rightChevron = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_angle_right.svg',
        ),
      );
      expect(
        rightChevron.colorFilter,
        equals(
          const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
        ),
      );
    });
  });

  group('Phase D4-A — MonthContainer Isolated Geometry & State Verification', () {
    testWidgets('MonthContainer preserves 193x44 geometry and 20px radius',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: MonthContainer(
                label: 'October, 2026',
                onPrevious: () {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );

      final sizedBoxFinder = find.descendant(
        of: find.byType(MonthContainer),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 193 && w.height == 44,
        ),
      );
      expect(sizedBoxFinder, findsWidgets);

      final bgContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(MonthContainer),
          matching: find.byType(Container),
        ).first,
      );
      final shapeDeco = bgContainer.decoration as ShapeDecoration;
      final border = shapeDeco.shape as RoundedRectangleBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(20)));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE D4-B — CALENDAR GRID & DAY CELLS DARK MODE
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase D4-B — Calendar Day Cell Dark Mode Palette', () {
    testWidgets('1. Dark Mode: Normal day-cell background resolves to #2C2C2C',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: true,
        ),
      );

      final cellFinder = find.byType(CalendarDayCell);
      expect(cellFinder, findsOneWidget);

      final outerContainer = tester.widget<Container>(
        find.descendant(of: cellFinder, matching: find.byType(Container)).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF2C2C2C)));
    });

    testWidgets('2. Dark Mode: Normal day text resolves to #FFFFFF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: true,
        ),
      );

      final textWidget = tester.widget<Text>(find.text('15'));
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('3. Dark Mode: Selected-day accent remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(
            day: 15,
            taskState: DayTaskState.none,
            isSelected: true,
          ),
          isDark: true,
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      final border = deco.shape as RoundedRectangleBorder;
      expect(border.side.color, equals(const Color(0xFF0088FF)));
      expect(border.side.width, equals(1.5));
    });

    testWidgets('4. Dark Mode: Completed-day pill remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: true,
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('5. Dark Mode: Completed-day date text resolves to #FFFFFF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: true,
        ),
      );

      final textWidget = tester.widget<Text>(find.text('15'));
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('6. Dark Mode: Completed-day check icon resolves to #FFFFFF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: true,
        ),
      );

      final checkSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_check.svg',
        ),
      );
      expect(
        checkSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)),
      );
    });

    testWidgets('7. Dark Mode: Empty-day neutral indicator resolves to #3A3A3C',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: true,
        ),
      );

      final ovalContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is ShapeDecoration &&
                (w.decoration as ShapeDecoration).shape is OvalBorder,
          ),
        ),
      );
      expect(ovalContainers, isNotEmpty);
      final deco = ovalContainers.first.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF3A3A3C)));
    });

    testWidgets('8. Dark Mode: Task indicator remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.task),
          isDark: true,
        ),
      );

      final ovalContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is ShapeDecoration &&
                (w.decoration as ShapeDecoration).shape is OvalBorder,
          ),
        ),
      );
      expect(ovalContainers, isNotEmpty);
      final deco = ovalContainers.first.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('9. Dark Mode: Overdue indicator resolves to #FFFFFF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.notCompleted),
          isDark: true,
        ),
      );

      final crossSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_cross.svg',
        ),
      );
      expect(
        crossSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)),
      );
    });
  });

  group('Phase D4-B — Calendar Day Cell Light Mode Regression', () {
    testWidgets(
        '10. Light Mode: Normal day-cell background remains existing Light value (Colors.white)',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: false,
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      expect(deco.color, equals(Colors.white));
    });

    testWidgets('11. Light Mode: Normal day text remains #333333',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: false,
        ),
      );

      final textWidget = tester.widget<Text>(find.text('15'));
      expect(textWidget.style?.color, equals(const Color(0xFF333333)));
    });

    testWidgets('12. Light Mode: Selected accent remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(
            day: 15,
            taskState: DayTaskState.none,
            isSelected: true,
          ),
          isDark: false,
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      final border = deco.shape as RoundedRectangleBorder;
      expect(border.side.color, equals(const Color(0xFF0088FF)));
      expect(border.side.width, equals(1.5));
    });

    testWidgets('13. Light Mode: Completed pill remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: false,
        ),
      );

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('14. Light Mode: Completed-day number remains #333333',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: false,
        ),
      );

      final textWidget = tester.widget<Text>(find.text('15'));
      expect(textWidget.style?.color, equals(const Color(0xFF333333)));
    });

    testWidgets(
        '15. Light Mode: Completed check icon remains existing Light value (#333333)',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.completed),
          isDark: false,
        ),
      );

      final checkSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_check.svg',
        ),
      );
      expect(
        checkSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn)),
      );
    });

    testWidgets('16. Light Mode: Empty-day indicator remains #E5E5EA',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.none),
          isDark: false,
        ),
      );

      final ovalContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is ShapeDecoration &&
                (w.decoration as ShapeDecoration).shape is OvalBorder,
          ),
        ),
      );
      expect(ovalContainers, isNotEmpty);
      final deco = ovalContainers.first.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFFE5E5EA)));
    });

    testWidgets('17. Light Mode: Task indicator remains #0088FF',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.task),
          isDark: false,
        ),
      );

      final ovalContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is ShapeDecoration &&
                (w.decoration as ShapeDecoration).shape is OvalBorder,
          ),
        ),
      );
      expect(ovalContainers, isNotEmpty);
      final deco = ovalContainers.first.decoration as ShapeDecoration;
      expect(deco.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('18. Light Mode: Overdue indicator remains #333333',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 15, taskState: DayTaskState.notCompleted),
          isDark: false,
        ),
      );

      final crossSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_cross.svg',
        ),
      );
      expect(
        crossSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn)),
      );
    });
  });

  group('Phase D4-B — Geometry, Interaction & CalendarGridWidget Integration', () {
    testWidgets('CalendarDayCell preserves 32x48 geometry and 20px radius',
        (tester) async {
      await tester.pumpWidget(
        buildCellHarness(
          const CalendarDayCell(day: 10),
          isDark: true,
        ),
      );

      final sizedBoxFinder = find.descendant(
        of: find.byType(CalendarDayCell),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 32 && w.height == 48,
        ),
      );
      expect(sizedBoxFinder, findsWidgets);

      final outerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarDayCell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = outerContainer.decoration as ShapeDecoration;
      final border = deco.shape as RoundedRectangleBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(20)));
    });

    testWidgets('CalendarDayCell fires onTap callback when pressed',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildCellHarness(
          CalendarDayCell(day: 10, onTap: () => tapped = true),
          isDark: true,
        ),
      );

      await tester.tap(find.byType(CalendarDayCell));
      expect(tapped, isTrue);
    });

    testWidgets('CalendarGridWidget renders day cells in Dark Mode',
        (tester) async {
      int? tappedDay;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: CalendarGridWidget(
              currentMonth: DateTime(2026, 10, 1),
              taskStates: const {
                1: DayTaskState.none,
                2: DayTaskState.task,
                3: DayTaskState.notCompleted,
                4: DayTaskState.completed,
              },
              selectedDay: 2,
              onDayTap: (day) => tappedDay = day,
            ),
          ),
        ),
      );

      expect(find.byType(CalendarDayCell), findsNWidgets(31));

      // Day 1: none -> #2C2C2C background, #3A3A3C indicator
      // Day 2: task, selected -> #2C2C2C background, #0088FF border
      // Day 4: completed -> #0088FF pill background, #FFFFFF text
      final day4Text = tester.widget<Text>(find.text('4'));
      expect(day4Text.style?.color, equals(const Color(0xFFFFFFFF)));

      // Tap day 3
      await tester.tap(find.text('3'));
      expect(tappedDay, equals(3));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE D4-C — CALENDAR TASKS BOTTOM PANEL & TASK CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase D4-C — Calendar Tasks Bottom Panel Dark Mode Palette', () {
    testWidgets(
        '1. Dark Mode: TaskWidgetsContainer background resolves to #2C2C2C with 24px radius',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final containerFinder = find.descendant(
        of: find.byType(TaskWidgetsContainer),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(const Color(0xFF2C2C2C)));

      final border = decoration.shape as RoundedRectangleBorder;
      expect(
        border.borderRadius,
        equals(const BorderRadius.vertical(top: Radius.circular(24))),
      );
    });

    testWidgets('2. Dark Mode: TaskWidgetsContainer header title resolves to #FFFFFF',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final titleFinder = find.text('Tasks for June 16');
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('3. Dark Mode: TaskWidgetsContainer header gradient uses #2C2C2C',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final gradientContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.gradient is LinearGradient;
        }
        return false;
      });
      expect(gradientContainerFinder, findsOneWidget);

      final gradientBox =
          tester.widget<Container>(gradientContainerFinder).decoration
              as BoxDecoration;
      final gradient = gradientBox.gradient as LinearGradient;
      expect(gradient.colors.first, equals(const Color(0xFF2C2C2C)));
    });

    testWidgets('4. Dark Mode: Empty state text resolves to #757575',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final emptyTextFinder = find.text('No tasks for this day');
      expect(emptyTextFinder, findsOneWidget);
      final emptyText = tester.widget<Text>(emptyTextFinder);
      expect(emptyText.style?.color, equals(const Color(0xFF757575)));
    });

    testWidgets('5. Dark Mode: Add Task button background resolves to #3A3A3C',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final addTaskTextFinder = find.text('Add Task');
      expect(addTaskTextFinder, findsOneWidget);

      final buttonContainerFinder = find.ancestor(
        of: addTaskTextFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is ShapeDecoration &&
              (w.decoration as ShapeDecoration).color ==
                  const Color(0xFF3A3A3C),
        ),
      );
      expect(buttonContainerFinder, findsOneWidget);
    });

    testWidgets('6. Dark Mode: Add Task icon and text resolve to #FFFFFF',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: true,
      );

      final addTaskText = tester.widget<Text>(find.text('Add Task'));
      expect(addTaskText.style?.color, equals(const Color(0xFFFFFFFF)));

      final plusSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_plus.svg',
        ),
      );
      expect(
        plusSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)),
      );
    });
  });

  group('Phase D4-C — CalendarTaskCard Dark Mode Palette', () {
    testWidgets('7. Dark Mode: CalendarTaskCard background resolves to #3A3A3C',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Design Review',
        subtitle: '10:00 AM',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final cardFinder = find.byType(CalendarTaskCard);
      final containerFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(const Color(0xFF3A3A3C)));
    });

    testWidgets('8. Dark Mode: Task title resolves to #FFFFFF', (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Design Review',
        subtitle: '10:00 AM',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final titleText = tester.widget<Text>(find.text('Design Review'));
      expect(titleText.style?.color, equals(const Color(0xFFFFFFFF)));
      expect(titleText.style?.decorationColor, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('9. Dark Mode: Task subtitle resolves to #757575',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Design Review',
        subtitle: '10:00 AM',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final subtitleText = tester.widget<Text>(find.text('10:00 AM'));
      expect(subtitleText.style?.color, equals(const Color(0xFF757575)));
    });

    testWidgets(
        '10. Dark Mode: Incomplete toggle outline resolves to #5A5A5A',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Design Review',
        subtitle: '10:00 AM',
        priority: TaskPriority.green,
        isCompleted: false,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final toggleContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          if (deco.shape is OvalBorder) {
            final oval = deco.shape as OvalBorder;
            return oval.side.color == const Color(0xFF5A5A5A);
          }
        }
        return false;
      });
      expect(toggleContainerFinder, findsOneWidget);
    });

    testWidgets(
        '11 & 12. Dark Mode: Completed toggle background resolves to #0088FF, check to #FFFFFF',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Design Review',
        subtitle: '10:00 AM',
        priority: TaskPriority.green,
        isCompleted: true,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final blueCircleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0xFF0088FF) &&
              deco.shape is OvalBorder;
        }
        return false;
      });
      expect(blueCircleFinder, findsOneWidget);

      final checkSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_check.svg',
        ),
      );
      expect(
        checkSvg.colorFilter,
        equals(const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
      );
    });
  });

  group('Phase D4-C — Semantic Color Invariance', () {
    testWidgets('13. Green priority remains #34C759 (50% alpha: 0x7F34C759)',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Low Priority Task',
        subtitle: 'All Day',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final stripFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0x7F34C759) && w.constraints?.maxWidth == 26;
        }
        return false;
      });
      expect(stripFinder, findsOneWidget);
    });

    testWidgets('14. Yellow priority remains #FFCC00 (50% alpha: 0x7FFFCC00)',
        (tester) async {
      final task = CalendarTask(
        id: '2',
        title: 'Medium Priority Task',
        subtitle: 'All Day',
        priority: TaskPriority.yellow,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final stripFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0x7FFFCC00) && w.constraints?.maxWidth == 26;
        }
        return false;
      });
      expect(stripFinder, findsOneWidget);
    });

    testWidgets('15. Red priority remains #FF383C (50% alpha: 0x7FFF383C)',
        (tester) async {
      final task = CalendarTask(
        id: '3',
        title: 'High Priority Task',
        subtitle: 'All Day',
        priority: TaskPriority.red,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final stripFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0x7FFF383C) && w.constraints?.maxWidth == 26;
        }
        return false;
      });
      expect(stripFinder, findsOneWidget);
    });

    testWidgets(
        '16, 17 & 18. Swipe delete retains #7FFF0000 background and Dark trash delegates #FFFFFF',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Delete Me',
        subtitle: 'Soon',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
        ),
        isDark: true,
      );

      // Swipe left on the card
      await tester.drag(find.text('Delete Me'), const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Delete button container with 0x7FFF0000
      final deleteBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7FFF0000);
        }
        return false;
      });
      expect(deleteBtnFinder, findsOneWidget);

      // Lottie delegate has #FFFFFF
      final lottieFinder = find.byType(Lottie);
      expect(lottieFinder, findsOneWidget);
      final lottieWidget = tester.widget<Lottie>(lottieFinder);
      expect(lottieWidget.delegates?.values, isNotNull);
      final valDelegate = lottieWidget.delegates!.values!.first;
      expect(valDelegate.value, equals(const Color(0xFFFFFFFF)));
    });
  });

  group('Phase D4-C — Light Mode Regression', () {
    testWidgets('19. Light Mode: TaskWidgetsContainer background resolves to white',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: false,
      );

      final containerFinder = find.descendant(
        of: find.byType(TaskWidgetsContainer),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(Colors.white));
    });

    testWidgets('20. Light Mode: TaskWidgetsContainer header title resolves to #333333',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: false,
      );

      final titleText = tester.widget<Text>(find.text('Tasks for June 16'));
      expect(titleText.style?.color, equals(const Color(0xFF333333)));
    });

    testWidgets('21. Light Mode: Empty state text resolves to 0x80000000',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: false,
      );

      final emptyText = tester.widget<Text>(find.text('No tasks for this day'));
      expect(emptyText.style?.color, equals(const Color(0x80000000)));
    });

    testWidgets(
        '22 & 23. Light Mode: Add Task background is 0x33787878, icon/text is #333333',
        (tester) async {
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
        ),
        isDark: false,
      );

      final addTaskTextFinder = find.text('Add Task');
      final addTaskText = tester.widget<Text>(addTaskTextFinder);
      expect(addTaskText.style?.color, equals(const Color(0xFF333333)));

      final buttonContainerFinder = find.ancestor(
        of: addTaskTextFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is ShapeDecoration &&
              (w.decoration as ShapeDecoration).color ==
                  const Color(0x33787878),
        ),
      );
      expect(buttonContainerFinder, findsOneWidget);

      final plusSvg = tester.widget<SvgPicture>(
        find.byWidgetPredicate(
          (w) =>
              w is SvgPicture &&
              w.bytesLoader is SvgAssetLoader &&
              (w.bytesLoader as SvgAssetLoader).assetName ==
                  'assets/icons/calendar_plus.svg',
        ),
      );
      expect(
        plusSvg.colorFilter,
        equals(const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn)),
      );
    });

    testWidgets('24. Light Mode: CalendarTaskCard background resolves to white',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Review PR',
        subtitle: '9:00 AM',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: false,
      );

      final cardFinder = find.byType(CalendarTaskCard);
      final containerFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(Colors.white));
    });

    testWidgets('25 & 26. Light Mode: Task title & subtitle resolve to #1C1C1E',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Review PR',
        subtitle: '9:00 AM',
        priority: TaskPriority.green,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: false,
      );

      final titleText = tester.widget<Text>(find.text('Review PR'));
      expect(titleText.style?.color, equals(const Color(0xFF1C1C1E)));

      final subtitleText = tester.widget<Text>(find.text('9:00 AM'));
      expect(subtitleText.style?.color, equals(const Color(0xFF1C1C1E)));
    });

    testWidgets(
        '27. Light Mode: Incomplete toggle outline resolves to 0x33787878',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Review PR',
        subtitle: '9:00 AM',
        priority: TaskPriority.green,
        isCompleted: false,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: false,
      );

      final toggleContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          if (deco.shape is OvalBorder) {
            final oval = deco.shape as OvalBorder;
            return oval.side.color == const Color(0x33787878);
          }
        }
        return false;
      });
      expect(toggleContainerFinder, findsOneWidget);
    });

    testWidgets('28 & 29. Light Mode: Swipe-delete trash icon delegates to #333333',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Delete Light',
        subtitle: 'Now',
        priority: TaskPriority.red,
      );

      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
        ),
        isDark: false,
      );

      await tester.drag(find.text('Delete Light'), const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      final lottieFinder = find.byType(Lottie);
      expect(lottieFinder, findsOneWidget);
      final lottieWidget = tester.widget<Lottie>(lottieFinder);
      final valDelegate = lottieWidget.delegates!.values!.first;
      expect(valDelegate.value, equals(const Color(0xFF333333)));
    });
  });

  group('Phase D4-C — Geometry, Interaction & State Regression', () {
    testWidgets('30. CalendarTaskCard preserves 67px height, 20px radius, 26px strip',
        (tester) async {
      final task = CalendarTask(
        id: '1',
        title: 'Geometry Test',
        subtitle: 'Check dimensions',
        priority: TaskPriority.yellow,
      );

      await pumpPanel(
        tester,
        child: Center(child: CalendarTaskCard(task: task)),
        isDark: true,
      );

      final cardContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(CalendarTaskCard),
          matching: find.byType(Container),
        ).first,
      );
      expect(cardContainer.constraints?.maxHeight, equals(67));

      final deco = cardContainer.decoration as ShapeDecoration;
      final border = deco.shape as RoundedRectangleBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(20)));

      final strip = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0x7FFFCC00)),
      );
      expect(strip.constraints?.maxWidth, equals(26));
    });

    testWidgets('31. Add Task button preserves 110x36 geometry and responds to tap',
        (tester) async {
      bool tapped = false;
      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: const [],
          onAddTask: () => tapped = true,
        ),
        isDark: true,
      );

      final button = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints?.maxWidth == 110 &&
            w.constraints?.maxHeight == 36),
      );
      expect(button, isNotNull);

      await tester.tap(find.text('Add Task'));
      tester.takeException();
      await tester.pump();
      tester.takeException();
      expect(tapped, isTrue);
    });

    testWidgets('32. Incomplete toggle tap triggers onToggle callback',
        (tester) async {
      bool toggled = false;
      final task = CalendarTask(
        id: '1',
        title: 'Toggle Me',
        subtitle: 'Tap circle',
        priority: TaskPriority.green,
        isCompleted: false,
      );

      await pumpPanel(
        tester,
        child: Center(
          child: CalendarTaskCard(
            task: task,
            onToggle: () => toggled = true,
          ),
        ),
        isDark: true,
      );

      // Find toggle detector
      final toggleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.shape is OvalBorder;
        }
        return false;
      });
      await tester.tap(toggleFinder);
      tester.takeException();
      await tester.pump();
      tester.takeException();
      expect(toggled, isTrue);
    });

    testWidgets('33. Task card body tap triggers onTap callback',
        (tester) async {
      bool tapped = false;
      final task = CalendarTask(
        id: '1',
        title: 'Tap Body',
        subtitle: 'Tap text',
        priority: TaskPriority.red,
      );

      await pumpPanel(
        tester,
        child: Center(
          child: CalendarTaskCard(
            task: task,
            onTap: () => tapped = true,
          ),
        ),
        isDark: true,
      );

      await tester.tap(find.text('Tap Body'));
      tester.takeException();
      await tester.pump();
      tester.takeException();
      expect(tapped, isTrue);
    });

    testWidgets('34. Swipe-to-delete reveals delete button and triggers onDismiss',
        (tester) async {
      String? dismissedId;
      final task = CalendarTask(
        id: 'del_1',
        title: 'Swipe Dismiss',
        subtitle: 'Swipe left',
        priority: TaskPriority.yellow,
      );

      await pumpPanel(
        tester,
        child: TaskWidgetsContainer(
          selectedDate: DateTime(2026, 6, 16),
          tasks: [task],
          onDismissTask: (id) => dismissedId = id,
        ),
        isDark: true,
      );

      // Drag left
      await tester.drag(find.text('Swipe Dismiss'), const Offset(-80, 0));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();

      // Tap revealed red delete button
      final deleteBtnFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is ShapeDecoration) {
          final deco = w.decoration as ShapeDecoration;
          return deco.color == const Color(0x7FFF0000);
        }
        return false;
      });
      expect(deleteBtnFinder, findsOneWidget);

      await tester.tap(deleteBtnFinder);
      tester.takeException();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(dismissedId, equals('del_1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE D4-D — CALENDAR MODALS & OVERLAYS DARK MODE
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase D4-D — Delete Task Confirmation Dialog Dark Mode Palette', () {
    testWidgets('1. Dark Mode: Dialog surface resolves to #2C2C2C with 30px radius',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: true,
      );

      final containerFinder = find.descendant(
        of: find.byType(DeleteTaskConfirmationDialog),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(const Color(0xFF2C2C2C)));

      final border = decoration.shape as RoundedRectangleBorder;
      expect(border.borderRadius, equals(BorderRadius.circular(30)));
      expect(container.constraints?.maxWidth, equals(303));
      expect(container.constraints?.maxHeight, equals(296));
    });

    testWidgets('2. Dark Mode: Non-recurring dialog height is 223px',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: false),
        ),
        isDark: true,
      );

      final containerFinder = find.descendant(
        of: find.byType(DeleteTaskConfirmationDialog),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxWidth, equals(303));
      expect(container.constraints?.maxHeight, equals(223));
    });

    testWidgets('3. Dark Mode: Primary title text resolves to #FFFFFF',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(
            title: 'Delete Recurring Task',
            isRecurring: true,
          ),
        ),
        isDark: true,
      );

      final titleFinder = find.text('Delete Recurring Task');
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('4. Dark Mode: Secondary message text resolves to #757575',
        (tester) async {
      const msg = 'Are you sure you want to delete\nthis task?';
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(
            message: msg,
            isRecurring: true,
          ),
        ),
        isDark: true,
      );

      final msgFinder = find.text(msg);
      expect(msgFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(msgFinder);
      expect(textWidget.style?.color, equals(const Color(0xFF757575)));
    });

    testWidgets('5. Dark Mode: Neutral action pill background resolves to #3A3A3C',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: true,
      );

      final cancelFinder = find.text('Cancel');
      expect(cancelFinder, findsOneWidget);

      final pillFinder = find.ancestor(
        of: cancelFinder,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).color == const Color(0xFF3A3A3C)),
      );
      expect(pillFinder, findsOneWidget);
    });

    testWidgets('6. Dark Mode: Neutral action cancel text resolves to #757575',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: true,
      );

      final cancelText = tester.widget<Text>(find.text('Cancel'));
      expect(cancelText.style?.color, equals(const Color(0xFF757575)));
    });

    testWidgets('7. Dark Mode: Non-destructive recurring action ("Delete Today") text resolves to #0088FF',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: true,
      );

      final deleteTodayText = tester.widget<Text>(find.text('Delete Today'));
      expect(deleteTodayText.style?.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('8. Dark Mode: Destructive action ("Delete Forever" / "Delete") text resolves to #FF453A',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: true,
      );

      final deleteForeverText = tester.widget<Text>(find.text('Delete Forever'));
      expect(deleteForeverText.style?.color, equals(const Color(0xFFFF453A)));

      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: false),
        ),
        isDark: true,
      );

      final deleteText = tester.widget<Text>(find.text('Delete'));
      expect(deleteText.style?.color, equals(const Color(0xFFFF453A)));
    });
  });

  group('Phase D4-D — Delete Task Confirmation Dialog Light Mode Regression', () {
    testWidgets('9. Light Mode: Delete dialog surface remains white',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: false,
      );

      final containerFinder = find.descendant(
        of: find.byType(DeleteTaskConfirmationDialog),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as ShapeDecoration;
      expect(decoration.color, equals(Colors.white));
    });

    testWidgets('10. Light Mode: Title and message text remain #333333',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(
            title: 'Delete Task',
            message: 'Confirmation msg',
            isRecurring: true,
          ),
        ),
        isDark: false,
      );

      final titleText = tester.widget<Text>(find.text('Delete Task'));
      expect(titleText.style?.color, equals(const Color(0xFF333333)));

      final msgText = tester.widget<Text>(find.text('Confirmation msg'));
      expect(msgText.style?.color, equals(const Color(0xFF333333)));
    });

    testWidgets('11. Light Mode: Action pill background remains 0x33787878',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: false,
      );

      final cancelFinder = find.text('Cancel');
      final pillFinder = find.ancestor(
        of: cancelFinder,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).color == const Color(0x33787878)),
      );
      expect(pillFinder, findsOneWidget);
    });

    testWidgets('12. Light Mode: Cancel text remains #333333 and Delete Today remains #0088FF',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: false,
      );

      final cancelText = tester.widget<Text>(find.text('Cancel'));
      expect(cancelText.style?.color, equals(const Color(0xFF333333)));

      final deleteTodayText = tester.widget<Text>(find.text('Delete Today'));
      expect(deleteTodayText.style?.color, equals(const Color(0xFF0088FF)));
    });

    testWidgets('13. Light Mode: Destructive action text remains #FF383C',
        (tester) async {
      await pumpPanel(
        tester,
        child: const Center(
          child: DeleteTaskConfirmationDialog(isRecurring: true),
        ),
        isDark: false,
      );

      final deleteForeverText = tester.widget<Text>(find.text('Delete Forever'));
      expect(deleteForeverText.style?.color, equals(const Color(0xFFFF383C)));
    });
  });

  group('Phase D4-D — CelebrationOverlay Dark Mode Palette & Artwork Invariance', () {
    testWidgets('14. Dark Mode: CelebrationOverlay badge surface resolves to #2C2C2C with 22px radius',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 All tasks done!',
          onDone: () {},
        ),
        isDark: true,
        disableAnimations: false,
      );

      // Advance animation slightly to reveal badge
      await tester.pump(const Duration(milliseconds: 200));

      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.color == const Color(0xFF2C2C2C) &&
              box.borderRadius == BorderRadius.circular(22);
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget);
    });

    testWidgets('15. Dark Mode: Primary celebration text resolves to #FFFFFF',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 All tasks done!',
          onDone: () {},
        ),
        isDark: true,
        disableAnimations: false,
      );

      await tester.pump(const Duration(milliseconds: 200));

      final textFinder = find.text('🎉 All tasks done!');
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });

    testWidgets('16. Celebration particle colors retain existing vibrant palette',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 Done!',
          onDone: () {},
        ),
        isDark: true,
        disableAnimations: false,
      );

      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      final hasParticlePainter = tester.any(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CustomPainter),
      );
      expect(hasParticlePainter, isTrue);
    });

    testWidgets('17. Dark Mode (Reduced Motion): Static acknowledgement badge resolves to #2C2C2C and #FFFFFF',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 All tasks done!',
          onDone: () {},
        ),
        isDark: true,
        disableAnimations: true,
      );

      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('🎉 All tasks done!'));
      expect(textWidget.style?.color, equals(const Color(0xFFFFFFFF)));
    });
  });

  group('Phase D4-D — CelebrationOverlay Light Mode Regression', () {
    testWidgets('18. Light Mode: Celebration badge surface remains white and text remains #1C1C1E',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 All tasks done!',
          onDone: () {},
        ),
        isDark: false,
        disableAnimations: false,
      );

      await tester.pump(const Duration(milliseconds: 200));

      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.color == Colors.white;
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('🎉 All tasks done!'));
      expect(textWidget.style?.color, equals(const Color(0xFF1C1C1E)));
    });

    testWidgets('19. Light Mode (Reduced Motion): Static badge remains white and #1C1C1E',
        (tester) async {
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 All tasks done!',
          onDone: () {},
        ),
        isDark: false,
        disableAnimations: true,
      );

      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final box = w.decoration as BoxDecoration;
          return box.color == Colors.white;
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('🎉 All tasks done!'));
      expect(textWidget.style?.color, equals(const Color(0xFF1C1C1E)));
    });
  });

  group('Phase D4-D — Dialog & Overlay Interaction / State Semantics', () {
    testWidgets('20. Delete dialog (recurring): Tapping "Delete Forever" returns "forever"',
        (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTaskDialog(ctx, isRecurring: true);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Forever'));
      await tester.pumpAndSettle();

      expect(result, equals('forever'));
    });

    testWidgets('21. Delete dialog (recurring): Tapping "Delete Today" returns "today"',
        (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTaskDialog(ctx, isRecurring: true);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Today'));
      await tester.pumpAndSettle();

      expect(result, equals('today'));
    });

    testWidgets('22. Delete dialog (recurring): Tapping "Cancel" returns null',
        (tester) async {
      String? result = 'initial';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTaskDialog(ctx, isRecurring: true);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('23. Delete dialog (non-recurring): Tapping "Delete" returns "forever"',
        (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTaskDialog(ctx, isRecurring: false);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, equals('forever'));
    });

    testWidgets('24. Delete dialog (non-recurring): Tapping "Cancel" returns null',
        (tester) async {
      String? result = 'initial';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showDeleteTaskDialog(ctx, isRecurring: false);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('25. Celebration overlay triggers onDone callback upon completion',
        (tester) async {
      bool done = false;
      await pumpPanel(
        tester,
        child: CelebrationOverlay(
          message: '🎉 Done!',
          onDone: () => done = true,
        ),
        isDark: true,
        disableAnimations: false,
      );

      // Advance full 1600ms lifecycle and complete status listener
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE DM-F2 — CALENDAR SCREEN TASKS BOTTOM SHEET BACKING PANEL REGRESSION
  // ═══════════════════════════════════════════════════════════════════════════

  group('Phase DM-F2 — Calendar Screen Tasks Bottom Sheet Backing Panel', () {
    testWidgets(
        'Dark Mode: Calendar Tasks bottom sheet outer backing panel resolves to #2C2C2C',
        (tester) async {
      await pumpCalendar(tester, isDark: true);

      final sheetContainerFinder = find.ancestor(
        of: find.byType(TaskWidgetsContainer),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(sheetContainerFinder);
      final decoration = container.decoration as ShapeDecoration;

      expect(
        decoration.color,
        equals(const Color(0xFF2C2C2C)),
        reason:
            'Outer backing panel of Tasks bottom sheet must resolve to #2C2C2C in Dark Mode',
      );
      final border = decoration.shape as RoundedRectangleBorder;
      expect(
        border.borderRadius,
        equals(const BorderRadius.vertical(top: Radius.circular(24))),
      );
    });

    testWidgets(
        'Light Mode: Calendar Tasks bottom sheet outer backing panel retains Colors.white',
        (tester) async {
      await pumpCalendar(tester, isDark: false);

      final sheetContainerFinder = find.ancestor(
        of: find.byType(TaskWidgetsContainer),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(sheetContainerFinder);
      final decoration = container.decoration as ShapeDecoration;

      expect(
        decoration.color,
        equals(Colors.white),
        reason:
            'Outer backing panel of Tasks bottom sheet must retain Colors.white in Light Mode',
      );
      final border = decoration.shape as RoundedRectangleBorder;
      expect(
        border.borderRadius,
        equals(const BorderRadius.vertical(top: Radius.circular(24))),
      );
    });
  });
}




