import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/month_container.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/calendar_grid_widget.dart';
import 'package:quick_notes/views/screens/calendar_screen.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/screens/home_screen.dart';
import 'package:quick_notes/views/screens/settings_screen.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/premium/premium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableScreen(
    WidgetTester tester,
    Widget screen, {
    double viewportWidth = 412.0,
    double topPadding = 36.0,
  }) {
    tester.view.physicalSize = Size(viewportWidth, 844.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return MediaQuery(
      data: MediaQueryData(
        size: Size(viewportWidth, 844.0),
        padding: EdgeInsets.only(top: topPadding),
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
          home: screen,
        ),
      ),
    );
  }

  Finder findHeaderLeadingButton(WidgetTester tester, Type screenType) {
    if (screenType == CalendarScreen) {
      final monthContainerFinder = find.byType(MonthContainer);
      final headerSizedBoxFinder = find.ancestor(
        of: monthContainerFinder,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 44.0,
        ),
      ).first;
      return find.descendant(
        of: headerSizedBoxFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).first;
    } else if (screenType == FolderManagementScreen) {
      final headerKeyFinder = find.byKey(const ValueKey('search_inactive_header'));
      return find.descendant(
        of: headerKeyFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).first;
    } else {
      // HomeScreen or SettingsScreen
      final headerBarFinder = find.byType(AppHeaderBar);
      return find.descendant(
        of: headerBarFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).first;
    }
  }

  Finder findHeaderTrailingButton(WidgetTester tester, Type screenType) {
    if (screenType == CalendarScreen) {
      final monthContainerFinder = find.byType(MonthContainer);
      final headerSizedBoxFinder = find.ancestor(
        of: monthContainerFinder,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 44.0,
        ),
      ).first;
      return find.descendant(
        of: headerSizedBoxFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).last;
    } else if (screenType == FolderManagementScreen) {
      final headerKeyFinder = find.byKey(const ValueKey('search_inactive_header'));
      return find.descendant(
        of: headerKeyFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).last;
    } else {
      // HomeScreen or SettingsScreen
      final headerBarFinder = find.byType(AppHeaderBar);
      return find.descendant(
        of: headerBarFinder,
        matching: find.byType(BottomBarGlassSurface),
      ).last;
    }
  }

  group('TEST A — CALENDAR HEADER HEIGHT', () {
    testWidgets('MonthContainer resolves to exactly height 44.0 and not 46.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MonthContainer(label: 'January,2026'),
            ),
          ),
        ),
      );

      final monthContainerFinder = find.byType(MonthContainer);
      expect(monthContainerFinder, findsOneWidget);
      final size = tester.getSize(monthContainerFinder);
      expect(size.width, 193.0);
      expect(size.height, 44.0, reason: 'MonthContainer height must be exactly 44.0px');
    });

    testWidgets('CalendarScreen header row resolves to exactly 44.0px height', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(tester, const CalendarScreen()),
      );
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final monthContainerFinder = find.byType(MonthContainer);
      expect(monthContainerFinder, findsOneWidget);

      // The header SizedBox that wraps the Row must have height 44.0
      final headerSizedBoxFinder = find.ancestor(
        of: monthContainerFinder,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 44.0,
        ),
      );
      expect(headerSizedBoxFinder, findsAtLeastNWidgets(1));
    });
  });

  group('TEST B — CALENDAR VERTICAL ALIGNMENT', () {
    testWidgets('Calendar leading button rests at SafeArea.top + 12.0px without +1px drift', (tester) async {
      const topPadding = 36.0;
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const CalendarScreen(),
          topPadding: topPadding,
        ),
      );
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final leadingButton = findHeaderLeadingButton(tester, CalendarScreen);
      final offset = tester.getTopLeft(leadingButton);

      // Expected Y is exactly SafeArea.top + 12.0 = 36.0 + 12.0 = 48.0
      expect(offset.dy, topPadding + 12.0,
          reason: 'Calendar back button must sit at SafeArea.top + 12.0px (48.0px), with zero vertical offset');
    });
  });

  group('TEST C — WIDE VIEWPORT HORIZONTAL ALIGNMENT (W = 412.0px)', () {
    const wideWidth = 412.0;
    const topPadding = 36.0;

    testWidgets('CalendarScreen leading X = 24.0 and trailing X = 344.0 on W = 412.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const CalendarScreen(),
          viewportWidth: wideWidth,
          topPadding: topPadding,
        ),
      );
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final leading = findHeaderLeadingButton(tester, CalendarScreen);
      final trailing = findHeaderTrailingButton(tester, CalendarScreen);

      expect(tester.getTopLeft(leading).dx, 24.0, reason: 'Calendar leading button must sit at X = 24.0');
      expect(tester.getTopLeft(trailing).dx, wideWidth - 24.0 - 44.0, reason: 'Calendar trailing button must sit at X = 344.0');
    });

    testWidgets('FolderManagementScreen leading X = 24.0 and trailing X = 344.0 on W = 412.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
          viewportWidth: wideWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, FolderManagementScreen);
      final trailing = findHeaderTrailingButton(tester, FolderManagementScreen);

      expect(tester.getTopLeft(leading).dx, 24.0, reason: 'Folders leading button must sit at X = 24.0 without 402px centering drift');
      expect(tester.getTopLeft(trailing).dx, wideWidth - 24.0 - 44.0, reason: 'Folders trailing button must sit at X = 344.0');
    });

    testWidgets('SettingsScreen leading X = 24.0 and trailing X = 344.0 on W = 412.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const SettingsScreen(),
          viewportWidth: wideWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, SettingsScreen);
      final trailing = findHeaderTrailingButton(tester, SettingsScreen);

      expect(tester.getTopLeft(leading).dx, 24.0, reason: 'Settings leading button must sit at X = 24.0');
      expect(tester.getTopLeft(trailing).dx, wideWidth - 24.0 - 44.0, reason: 'Settings trailing button must sit at X = 344.0');
    });

    testWidgets('HomeScreen leading X = 24.0 and trailing X = 344.0 on W = 412.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const HomeScreen(),
          viewportWidth: wideWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, HomeScreen);
      final trailing = findHeaderTrailingButton(tester, HomeScreen);

      expect(tester.getTopLeft(leading).dx, 24.0, reason: 'Home leading button must sit at X = 24.0');
      expect(tester.getTopLeft(trailing).dx, wideWidth - 24.0 - 44.0, reason: 'Home trailing button must sit at X = 344.0');
    });
  });

  group('TEST D — NARROW VIEWPORT HORIZONTAL ALIGNMENT (W = 390.0px)', () {
    const narrowWidth = 390.0;
    const topPadding = 36.0;

    testWidgets('CalendarScreen leading X = 24.0 and trailing X = 322.0 on W = 390.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const CalendarScreen(),
          viewportWidth: narrowWidth,
          topPadding: topPadding,
        ),
      );
      tester.takeException();
      await tester.pump();
      tester.takeException();

      final leading = findHeaderLeadingButton(tester, CalendarScreen);
      final trailing = findHeaderTrailingButton(tester, CalendarScreen);

      expect(tester.getTopLeft(leading).dx, 24.0);
      expect(tester.getTopLeft(trailing).dx, narrowWidth - 24.0 - 44.0);
    });

    testWidgets('FolderManagementScreen leading X = 24.0 and trailing X = 322.0 on W = 390.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
          viewportWidth: narrowWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, FolderManagementScreen);
      final trailing = findHeaderTrailingButton(tester, FolderManagementScreen);

      expect(tester.getTopLeft(leading).dx, 24.0);
      expect(tester.getTopLeft(trailing).dx, narrowWidth - 24.0 - 44.0);
    });

    testWidgets('SettingsScreen leading X = 24.0 and trailing X = 322.0 on W = 390.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const SettingsScreen(),
          viewportWidth: narrowWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, SettingsScreen);
      final trailing = findHeaderTrailingButton(tester, SettingsScreen);

      expect(tester.getTopLeft(leading).dx, 24.0);
      expect(tester.getTopLeft(trailing).dx, narrowWidth - 24.0 - 44.0);
    });

    testWidgets('HomeScreen leading X = 24.0 and trailing X = 322.0 on W = 390.0px', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const HomeScreen(),
          viewportWidth: narrowWidth,
          topPadding: topPadding,
        ),
      );
      await tester.pumpAndSettle();

      final leading = findHeaderLeadingButton(tester, HomeScreen);
      final trailing = findHeaderTrailingButton(tester, HomeScreen);

      expect(tester.getTopLeft(leading).dx, 24.0);
      expect(tester.getTopLeft(trailing).dx, narrowWidth - 24.0 - 44.0);
    });
  });

  group('TEST E — CONTENT CONSTRAINT PRESERVATION', () {
    testWidgets('CalendarScreen content area retains maxWidth: 402.0 constraint', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          const CalendarScreen(),
          viewportWidth: 412.0,
        ),
      );
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // Find the ConstrainedBox wrapping CalendarGridWidget
      final calendarGridFinder = find.byType(CalendarGridWidget);
      expect(calendarGridFinder, findsOneWidget);

      final constrainedBoxFinder = find.ancestor(
        of: calendarGridFinder,
        matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 402.0,
        ),
      );
      expect(constrainedBoxFinder, findsOneWidget, reason: 'Calendar body must preserve 402px content constraint');
    });

    testWidgets('FolderManagementScreen content panel retains 402px clamp', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          tester,
          FolderManagementScreen(
            onMenuTap: () {},
            onNavigateToTab: (_) {},
          ),
          viewportWidth: 412.0,
        ),
      );
      await tester.pumpAndSettle();

      // Find the SizedBox in FolderManagementScreen with width 402.0
      final contentSizedBoxFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 402.0,
      );
      expect(contentSizedBoxFinder, findsAtLeastNWidgets(1),
          reason: 'Folders content panel must preserve 402px width clamp');
    });
  });
}
