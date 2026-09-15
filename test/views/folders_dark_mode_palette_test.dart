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
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';

class _TestNotesProvider extends NotesProvider {
  final List<Folder> _testFolders = [];

  @override
  List<Folder> get folders => _testFolders;

  void addTestFolder(Folder folder) {
    _testFolders.add(folder);
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildFoldersScreenHarness({
    required bool isDark,
    NotesProvider? notesProvider,
  }) {
    SharedPreferences.setMockInitialValues({});
    final provider = notesProvider ?? NotesProvider();

    return ChangeNotifierProvider<NotesProvider>.value(
      value: provider,
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

  group('Phase D3-C — Folders Screen Folder Card System Dark Mode Verification', () {
    Widget buildFolderCardHarness({
      required bool isDark,
      required Folder folder,
      int noteCount = 3,
      String query = '',
      VoidCallback? onCustomizeTap,
    }) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              height: 192,
              child: FolderGridCard(
                folder: folder,
                index: 0,
                noteCount: noteCount,
                query: query,
                onTap: () {},
                onCustomizeTap: onCustomizeTap,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
        'Dark Mode: Title resolves to #FFFFFF, badge bg resolves to #5A5A5A, badge text resolves to #FFFFFF',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: true,
        folder: folder,
        noteCount: 12,
      ));
      await tester.pumpAndSettle();

      // 1. Folder title resolves to #FFFFFF
      final titleRichText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FolderGridCard),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.maxLines == 1 &&
                w.overflow == TextOverflow.ellipsis,
          ),
        ),
      );
      final textSpan = titleRichText.text as TextSpan;
      expect(textSpan.children, isNotNull);
      final titleSpan = textSpan.children!.first as TextSpan;
      expect(titleSpan.text, 'Work Projects');
      expect(
        titleSpan.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Base folder title must resolve to #FFFFFF in Dark Mode',
      );

      // 2. Note count badge background resolves to #5A5A5A
      final badgeContainerFinder = find.ancestor(
        of: find.text('12'),
        matching: find.byType(Container),
      ).first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final badgeDec = badgeContainer.decoration as BoxDecoration;
      expect(
        badgeDec.color,
        const Color(0xFF5A5A5A),
        reason: 'Badge container background must resolve to #5A5A5A in Dark Mode',
      );

      // 3. Note count badge text resolves to #FFFFFF
      final countText = tester.widget<Text>(find.text('12'));
      expect(
        countText.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Badge count text must resolve to #FFFFFF in Dark Mode',
      );
    });

    testWidgets(
        'Dark Mode: Query highlight remains #D49200 and unhighlighted spans resolve to #FFFFFF',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: true,
        folder: folder,
        query: 'Work',
      ));
      await tester.pumpAndSettle();

      final titleRichText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FolderGridCard),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.maxLines == 1 &&
                w.overflow == TextOverflow.ellipsis,
          ),
        ),
      );
      final textSpan = titleRichText.text as TextSpan;
      final spans = textSpan.children!;

      // 4. Query highlight remains #D49200
      final highlightSpan = spans[0] as TextSpan;
      expect(highlightSpan.text, 'Work');
      expect(
        highlightSpan.style?.color,
        const Color(0xFFD49200),
        reason: 'Query highlight TextSpan must be #D49200 in Dark Mode',
      );

      // Unhighlighted remainder resolves to #FFFFFF
      final remainderSpan = spans[1] as TextSpan;
      expect(remainderSpan.text, ' Projects');
      expect(
        remainderSpan.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Unhighlighted remainder TextSpan must be #FFFFFF in Dark Mode',
      );
    });

    testWidgets(
        'Dark Mode: Physical folder artwork, paper, header, ruled lines, and customize button are invariant',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Work Projects',
        createdAt: DateTime.now(),
        colorHex: '0xFF4A90E2',
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: true,
        folder: folder,
        onCustomizeTap: () {},
      ));
      await tester.pumpAndSettle();

      // 5. Physical folder color remains exactly the supplied folder color
      final fgFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FolderFgPainter,
      );
      expect(fgFinder, findsOneWidget);
      final fgCustomPaint = tester.widget<CustomPaint>(fgFinder);
      final fgPainter = fgCustomPaint.painter as FolderFgPainter;
      expect(
        fgPainter.color,
        const Color(0xFF4A90E2),
        reason: 'FolderFgPainter color must strictly match folder.colorHex in Dark Mode',
      );

      // 6. Folder back-flap derived color remains unchanged
      final bgFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FolderBgPainter,
      );
      expect(bgFinder, findsOneWidget);
      final bgCustomPaint = tester.widget<CustomPaint>(bgFinder);
      final bgPainter = bgCustomPaint.painter as FolderBgPainter;
      final hsl = HSLColor.fromColor(const Color(0xFF4A90E2));
      final expectedDark =
          hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
      expect(
        bgPainter.color,
        expectedDark,
        reason: 'FolderBgPainter color must remain _darken(colorHex) in Dark Mode',
      );

      // 7. DecorativeNoteCard stationery remains invariant (paper #FFFFFF, header #FFCC00, ruled lines #E2E2DF)
      expect(find.byType(DecorativeNoteCard), findsNWidgets(2));
      final firstCard = find.byType(DecorativeNoteCard).first;

      final headerFinder = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == const Color(0xFFFFCC00),
        ),
      );
      expect(
        headerFinder,
        findsOneWidget,
        reason: 'DecorativeNoteCard header must remain #FFCC00 in Dark Mode',
      );

      final paperFinder = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color == Colors.white,
        ),
      );
      expect(
        paperFinder,
        findsOneWidget,
        reason: 'DecorativeNoteCard paper must remain Colors.white in Dark Mode',
      );

      final ruledLineFinder = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color ==
                  const Color(0xFFE2E2DF),
        ),
      );
      expect(
        ruledLineFinder,
        findsNWidgets(5),
        reason: 'DecorativeNoteCard must have 5 ruled lines with #E2E2DF in Dark Mode',
      );

      // 8. Customize button remains background #FFFFFF and icon #8E8E93
      final customizeContainerFinder = find.ancestor(
        of: find.byIcon(Icons.add_rounded),
        matching: find.byType(Container),
      ).first;
      final customizeContainer =
          tester.widget<Container>(customizeContainerFinder);
      final customizeDec = customizeContainer.decoration as BoxDecoration;
      expect(
        customizeDec.color,
        Colors.white,
        reason: 'Customize button background must remain Colors.white in Dark Mode',
      );
      expect(customizeDec.shape, BoxShape.circle);

      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(
        addIcon.color,
        const Color(0xFF8E8E93),
        reason: 'Customize button icon must remain #8E8E93 in Dark Mode',
      );
    });

    testWidgets(
        'Light Mode: Title remains #1C1C1E, badge bg remains #1A787880, badge text remains #555558',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Personal Notes',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: false,
        folder: folder,
        noteCount: 7,
      ));
      await tester.pumpAndSettle();

      // 9. Folder title remains #1C1C1E
      final titleRichText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FolderGridCard),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.maxLines == 1 &&
                w.overflow == TextOverflow.ellipsis,
          ),
        ),
      );
      final textSpan = titleRichText.text as TextSpan;
      final titleSpan = textSpan.children!.first as TextSpan;
      expect(
        titleSpan.style?.color,
        const Color(0xFF1C1C1E),
        reason: 'Base folder title must remain #1C1C1E in Light Mode',
      );

      // 10. Count badge background remains #1A787880
      final badgeContainerFinder = find.ancestor(
        of: find.text('7'),
        matching: find.byType(Container),
      ).first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final badgeDec = badgeContainer.decoration as BoxDecoration;
      expect(
        badgeDec.color,
        const Color(0x1A787880),
        reason: 'Badge container background must remain #1A787880 in Light Mode',
      );

      // 11. Count badge text remains #555558
      final countText = tester.widget<Text>(find.text('7'));
      expect(
        countText.style?.color,
        const Color(0xFF555558),
        reason: 'Badge count text must remain #555558 in Light Mode',
      );
    });

    testWidgets(
        'Light Mode: Query highlight remains #D49200 and unhighlighted spans remain #1C1C1E',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Personal Notes',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: false,
        folder: folder,
        query: 'Personal',
      ));
      await tester.pumpAndSettle();

      final titleRichText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FolderGridCard),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.maxLines == 1 &&
                w.overflow == TextOverflow.ellipsis,
          ),
        ),
      );
      final textSpan = titleRichText.text as TextSpan;
      final spans = textSpan.children!;

      // 12. Query highlight remains #D49200
      final highlightSpan = spans[0] as TextSpan;
      expect(highlightSpan.text, 'Personal');
      expect(
        highlightSpan.style?.color,
        const Color(0xFFD49200),
        reason: 'Query highlight TextSpan must remain #D49200 in Light Mode',
      );

      // Unhighlighted remainder remains #1C1C1E
      final remainderSpan = spans[1] as TextSpan;
      expect(remainderSpan.text, ' Notes');
      expect(
        remainderSpan.style?.color,
        const Color(0xFF1C1C1E),
        reason: 'Unhighlighted remainder TextSpan must remain #1C1C1E in Light Mode',
      );
    });

    testWidgets(
        'Light Mode: Physical artwork, stationery, and customize button remain unchanged',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Personal Notes',
        createdAt: DateTime.now(),
        colorHex: '0xFFE57373',
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: false,
        folder: folder,
        onCustomizeTap: () {},
      ));
      await tester.pumpAndSettle();

      // 13. Physical folder colors remain unchanged
      final fgFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FolderFgPainter,
      );
      final fgCustomPaint = tester.widget<CustomPaint>(fgFinder);
      final fgPainter = fgCustomPaint.painter as FolderFgPainter;
      expect(fgPainter.color, const Color(0xFFE57373));

      // 14. Decorative stationery remains unchanged
      final firstCard = find.byType(DecorativeNoteCard).first;
      final headerFinder = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == const Color(0xFFFFCC00),
        ),
      );
      expect(headerFinder, findsOneWidget);

      final paperFinder = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color == Colors.white,
        ),
      );
      expect(paperFinder, findsOneWidget);

      // 15. Customize button remains unchanged
      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(addIcon.color, const Color(0xFF8E8E93));
    });

    testWidgets(
        'Geometry Lock: Card dimensions, spacings, badge radius, and grid aspect ratio are strictly preserved',
        (tester) async {
      final folder = Folder(
        id: 'f1',
        name: 'Geometry Test',
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(buildFolderCardHarness(
        isDark: true,
        folder: folder,
      ));
      await tester.pumpAndSettle();

      // 16. Existing 150 × 154 folder graphic geometry remains unchanged
      final graphicSizedBoxFinder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 150.0 && w.height == 154.0,
      );
      expect(
        graphicSizedBoxFinder,
        findsOneWidget,
        reason: 'Folder graphic container must be exactly 150 × 154',
      );

      // 17. 12px graphic/title spacing remains unchanged
      final spacing12Finder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 12.0,
      );
      expect(
        spacing12Finder,
        findsOneWidget,
        reason: 'Spacing between graphic and title row must be exactly 12.0px',
      );

      // 18. 6px title/badge spacing remains unchanged
      final spacing6Finder = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 6.0,
      );
      expect(
        spacing6Finder,
        findsOneWidget,
        reason: 'Spacing between title and badge must be exactly 6.0px',
      );

      // 19. Badge radius remains 10px
      final badgeContainerFinder = find.ancestor(
        of: find.text('3'),
        matching: find.byType(Container),
      ).first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final badgeDec = badgeContainer.decoration as BoxDecoration;
      expect(
        badgeDec.borderRadius,
        BorderRadius.circular(10.0),
        reason: 'Badge border radius must remain 10px',
      );

      // 20. Grid aspect ratio remains 150 / 192 on FolderManagementScreen
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_test',
        name: 'Test Grid Folder',
        createdAt: DateTime.now(),
      ));
      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<GridView>(gridFinder);
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(
        delegate.childAspectRatio,
        150.0 / 192.0,
        reason: 'GridView childAspectRatio must be exactly 150.0 / 192.0',
      );
    });
  });
}


