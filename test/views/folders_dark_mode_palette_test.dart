import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/themes/app_theme.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/widgets/primary_screen_surface.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildFoldersScreenHarness({required bool isDark}) {
    SharedPreferences.setMockInitialValues({});
    final notesProvider = NotesProvider();

    return ChangeNotifierProvider<NotesProvider>.value(
      value: notesProvider,
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: FolderManagementScreen(
          onMenuTap: () {},
          onNavigateToTab: (_) {},
        ),
      ),
    );
  }

  group('Phase D3-A — Folders Screen Main Surfaces Verification', () {
    testWidgets(
        'Dark Mode: Upper Canvas resolves to #1E1E1E and Rounded Content Sheet resolves to #2C2C2C with 32px radii',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      // 1. Verify Upper Folders Canvas resolves to #1E1E1E
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final darkScaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(
        darkScaffold.backgroundColor,
        const Color(0xFF1E1E1E),
        reason: 'Folders Upper Canvas must be #1E1E1E in Dark Mode',
      );

      // 2. Verify Rounded Content Sheet resolves to #2C2C2C
      final surfaceFinder = find.byType(PrimaryScreenSurface);
      expect(surfaceFinder, findsOneWidget);
      final surfaceWidget = tester.widget<PrimaryScreenSurface>(surfaceFinder);
      expect(
        surfaceWidget.color,
        const Color(0xFF2C2C2C),
        reason: 'Folders PrimaryScreenSurface must receive explicit #2C2C2C in Dark Mode',
      );

      // 3. Verify internal Container decoration resolves to #2C2C2C and 32px top radii
      final innerContainerFinder = find.descendant(
        of: surfaceFinder,
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(innerContainerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(
        decoration.color,
        const Color(0xFF2C2C2C),
        reason: 'Folders Content Sheet rendered decoration color must be #2C2C2C',
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason: 'Folders Content Sheet must preserve 32px top-left and top-right radii',
      );
    });

    testWidgets(
        'Light Mode: Upper Canvas remains AppColors.background (#FFFFFF) and Rounded Content Sheet remains Colors.white with 32px radii',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: false));
      await tester.pumpAndSettle();

      // 1. Verify Upper Folders Canvas remains AppColors.background (white)
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final lightScaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(
        lightScaffold.backgroundColor,
        AppColors.background,
        reason: 'Folders Upper Canvas must remain AppColors.background (#FFFFFF) in Light Mode',
      );

      // 2. Verify Rounded Content Sheet receives Colors.white
      final surfaceFinder = find.byType(PrimaryScreenSurface);
      expect(surfaceFinder, findsOneWidget);
      final surfaceWidget = tester.widget<PrimaryScreenSurface>(surfaceFinder);
      expect(
        surfaceWidget.color,
        Colors.white,
        reason: 'Folders PrimaryScreenSurface must receive Colors.white in Light Mode',
      );

      // 3. Verify internal Container decoration resolves to Colors.white and 32px top radii
      final innerContainerFinder = find.descendant(
        of: surfaceFinder,
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(innerContainerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(
        decoration.color,
        Colors.white,
        reason: 'Folders Content Sheet rendered decoration color must be Colors.white in Light Mode',
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason: 'Folders Content Sheet must preserve 32px top-left and top-right radii in Light Mode',
      );
    });

    testWidgets(
        'Shared Component Safety: PrimaryScreenSurface default behavior remains unchanged for other consumers',
        (tester) async {
      // 1. Un-overridden PrimaryScreenSurface in Light Mode defaults to Colors.white
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: PrimaryScreenSurface(
              child: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PrimaryScreenSurface),
          matching: find.byType(Container),
        ).first,
      );
      final lightDec = lightContainer.decoration as BoxDecoration;
      expect(
        lightDec.color,
        Colors.white,
        reason: 'PrimaryScreenSurface without explicit color must default to Colors.white in Light Mode',
      );

      // 2. Un-overridden PrimaryScreenSurface in Dark Mode defaults to Color(0xFF121212)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: PrimaryScreenSurface(
              child: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PrimaryScreenSurface),
          matching: find.byType(Container),
        ).first,
      );
      final darkDec = darkContainer.decoration as BoxDecoration;
      expect(
        darkDec.color,
        const Color(0xFF121212),
        reason: 'PrimaryScreenSurface without explicit color must default to #121212 in Dark Mode for other screens',
      );
    });
  });

  group('Phase D3-B — Folders Screen Header & Search Dark Mode Verification', () {
    testWidgets(
        'Dark Mode: Header controls and active search bar resolve to #FFFFFF with #757575 hint, preserving D3-A surfaces',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      // ── 1. Inactive Header (Default State) ──
      // 1a. Back arrow resolves to #FFFFFF
      final inactiveBackFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                'assets/icons/angle_left.svg',
      );
      expect(inactiveBackFinder, findsOneWidget);
      final inactiveBackSvg = tester.widget<SvgPicture>(inactiveBackFinder);
      expect(
        inactiveBackSvg.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        reason: 'Folders Header Back Arrow must resolve to #FFFFFF in Dark Mode',
      );

      // 1b. Search icon resolves to #FFFFFF
      final searchIconFinder = find.byIcon(Icons.search_rounded);
      expect(searchIconFinder, findsOneWidget);
      final searchIcon = tester.widget<Icon>(searchIconFinder);
      expect(
        searchIcon.color,
        Colors.white,
        reason: 'Folders Header Search Icon must resolve to #FFFFFF in Dark Mode',
      );

      // ── 2. Active Search Header ──
      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      // 2a. Active Back arrow resolves to #FFFFFF
      final activeBackFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                'assets/icons/angle_left.svg',
      );
      expect(activeBackFinder, findsOneWidget);
      final activeBackSvg = tester.widget<SvgPicture>(activeBackFinder);
      expect(
        activeBackSvg.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        reason: 'Folders Active Search Header Back Arrow must resolve to #FFFFFF in Dark Mode',
      );

      // 2b. Entered search text style resolves to #FFFFFF
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(
        textField.style?.color,
        Colors.white,
        reason: 'Folders Search Input entered text color must resolve to #FFFFFF in Dark Mode',
      );

      // 2c. Search hint / placeholder resolves to #757575
      expect(
        textField.decoration?.hintStyle?.color,
        const Color(0xFF757575),
        reason: 'Folders Search Hint / Placeholder must resolve to #757575 in Dark Mode',
      );

      // 2d. Close / clear icon resolves to #FFFFFF
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);
      final closeIcon = tester.widget<Icon>(closeIconFinder);
      expect(
        closeIcon.color,
        Colors.white,
        reason: 'Folders Header Close/Clear Icon must resolve to #FFFFFF in Dark Mode',
      );

      // ── 3. D3-A Surfaces Preservation ──
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        const Color(0xFF1E1E1E),
        reason: 'Folders Upper Canvas must remain #1E1E1E in Dark Mode',
      );

      final surface = tester.widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        const Color(0xFF2C2C2C),
        reason: 'Folders Rounded Content Sheet must remain #2C2C2C in Dark Mode',
      );

      final containerWidget = tester.widget<Container>(
        find.descendant(
          of: find.byType(PrimaryScreenSurface),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason: 'Folders Content Sheet top radii must remain 32px',
      );
    });

    testWidgets(
        'Light Mode: Header controls and active search bar preserve existing colors (#1C1C1E and #8C8987)',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: false));
      await tester.pumpAndSettle();

      // ── 1. Inactive Header (Default State) ──
      // 1a. Back arrow remains #1C1C1E
      final inactiveBackFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                'assets/icons/angle_left.svg',
      );
      expect(inactiveBackFinder, findsOneWidget);
      final inactiveBackSvg = tester.widget<SvgPicture>(inactiveBackFinder);
      expect(
        inactiveBackSvg.colorFilter,
        const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
        reason: 'Folders Header Back Arrow must remain #1C1C1E in Light Mode',
      );

      // 1b. Search icon remains #1C1C1E
      final searchIconFinder = find.byIcon(Icons.search_rounded);
      expect(searchIconFinder, findsOneWidget);
      final searchIcon = tester.widget<Icon>(searchIconFinder);
      expect(
        searchIcon.color,
        const Color(0xFF1C1C1E),
        reason: 'Folders Header Search Icon must remain #1C1C1E in Light Mode',
      );

      // ── 2. Active Search Header ──
      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      // 2a. Active Back arrow remains #1C1C1E
      final activeBackFinder = find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName ==
                'assets/icons/angle_left.svg',
      );
      expect(activeBackFinder, findsOneWidget);
      final activeBackSvg = tester.widget<SvgPicture>(activeBackFinder);
      expect(
        activeBackSvg.colorFilter,
        const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
        reason: 'Folders Active Search Header Back Arrow must remain #1C1C1E in Light Mode',
      );

      // 2b. Entered search text style remains #1C1C1E
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(
        textField.style?.color,
        const Color(0xFF1C1C1E),
        reason: 'Folders Search Input entered text color must remain #1C1C1E in Light Mode',
      );

      // 2c. Search hint / placeholder remains #8C8987
      expect(
        textField.decoration?.hintStyle?.color,
        const Color(0xFF8C8987),
        reason: 'Folders Search Hint / Placeholder must remain #8C8987 in Light Mode',
      );

      // 2d. Close / clear icon remains #1C1C1E
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);
      final closeIcon = tester.widget<Icon>(closeIconFinder);
      expect(
        closeIcon.color,
        const Color(0xFF1C1C1E),
        reason: 'Folders Header Close/Clear Icon must remain #1C1C1E in Light Mode',
      );

      // ── 3. D3-A Surfaces Preservation in Light Mode ──
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        AppColors.background,
        reason: 'Folders Upper Canvas must remain AppColors.background in Light Mode',
      );

      final surface = tester.widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        Colors.white,
        reason: 'Folders Rounded Content Sheet must remain Colors.white in Light Mode',
      );
    });
  });
}
