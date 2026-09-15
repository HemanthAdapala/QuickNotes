import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/themes/app_theme.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/widgets/primary_screen_surface.dart';

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
}
