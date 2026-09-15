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
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';
import 'package:quick_notes/views/widgets/delete_confirmation_dialog.dart';
import 'package:quick_notes/premium/feature_access.dart';
import 'package:quick_notes/premium/premium_feature.dart';
import 'package:quick_notes/premium/premium_gate_sheet.dart';

class _FakeFeatureAccess implements FeatureAccess {
  final bool allowsCustomization;
  _FakeFeatureAccess({this.allowsCustomization = false});

  @override
  bool canAccess(PremiumFeature feature) {
    if (feature == PremiumFeature.folderCustomization) {
      return allowsCustomization;
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNotesProvider extends NotesProvider {
  final List<Folder> _testFolders = [];

  @override
  List<Folder> get folders => _testFolders;

  void addTestFolder(Folder folder) {
    _testFolders.add(folder);
    notifyListeners();
  }

  @override
  Future<void> createFolder(String name, {String? parentId}) async {
    _testFolders.add(Folder(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  @override
  Future<bool> deleteFolder(String id) async {
    _testFolders.removeWhere((f) => f.id == id);
    notifyListeners();
    return true;
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
        reason:
            'Folders PrimaryScreenSurface must receive explicit #2C2C2C in Dark Mode',
      );

      // 3. Verify internal Container decoration resolves to #2C2C2C and 32px top radii
      final innerContainerFinder = find
          .descendant(
            of: surfaceFinder,
            matching: find.byType(Container),
          )
          .first;
      final containerWidget = tester.widget<Container>(innerContainerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(
        decoration.color,
        const Color(0xFF2C2C2C),
        reason:
            'Folders Content Sheet rendered decoration color must be #2C2C2C',
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason:
            'Folders Content Sheet must preserve 32px top-left and top-right radii',
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
        reason:
            'Folders Upper Canvas must remain AppColors.background (#FFFFFF) in Light Mode',
      );

      // 2. Verify Rounded Content Sheet receives Colors.white
      final surfaceFinder = find.byType(PrimaryScreenSurface);
      expect(surfaceFinder, findsOneWidget);
      final surfaceWidget = tester.widget<PrimaryScreenSurface>(surfaceFinder);
      expect(
        surfaceWidget.color,
        Colors.white,
        reason:
            'Folders PrimaryScreenSurface must receive Colors.white in Light Mode',
      );

      // 3. Verify internal Container decoration resolves to Colors.white and 32px top radii
      final innerContainerFinder = find
          .descendant(
            of: surfaceFinder,
            matching: find.byType(Container),
          )
          .first;
      final containerWidget = tester.widget<Container>(innerContainerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;

      expect(
        decoration.color,
        Colors.white,
        reason:
            'Folders Content Sheet rendered decoration color must be Colors.white in Light Mode',
      );
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason:
            'Folders Content Sheet must preserve 32px top-left and top-right radii in Light Mode',
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
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final lightDec = lightContainer.decoration as BoxDecoration;
      expect(
        lightDec.color,
        Colors.white,
        reason:
            'PrimaryScreenSurface without explicit color must default to Colors.white in Light Mode',
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
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final darkDec = darkContainer.decoration as BoxDecoration;
      expect(
        darkDec.color,
        const Color(0xFF121212),
        reason:
            'PrimaryScreenSurface without explicit color must default to #121212 in Dark Mode for other screens',
      );
    });
  });

  group('Phase D3-B — Folders Screen Header & Search Dark Mode Verification',
      () {
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
        reason:
            'Folders Header Back Arrow must resolve to #FFFFFF in Dark Mode',
      );

      // 1b. Search icon resolves to #FFFFFF
      final searchIconFinder = find.byIcon(Icons.search_rounded);
      expect(searchIconFinder, findsOneWidget);
      final searchIcon = tester.widget<Icon>(searchIconFinder);
      expect(
        searchIcon.color,
        Colors.white,
        reason:
            'Folders Header Search Icon must resolve to #FFFFFF in Dark Mode',
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
        reason:
            'Folders Active Search Header Back Arrow must resolve to #FFFFFF in Dark Mode',
      );

      // 2b. Entered search text style resolves to #FFFFFF
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(
        textField.style?.color,
        Colors.white,
        reason:
            'Folders Search Input entered text color must resolve to #FFFFFF in Dark Mode',
      );

      // 2c. Search hint / placeholder resolves to #757575
      expect(
        textField.decoration?.hintStyle?.color,
        const Color(0xFF757575),
        reason:
            'Folders Search Hint / Placeholder must resolve to #757575 in Dark Mode',
      );

      // 2d. Close / clear icon resolves to #FFFFFF
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);
      final closeIcon = tester.widget<Icon>(closeIconFinder);
      expect(
        closeIcon.color,
        Colors.white,
        reason:
            'Folders Header Close/Clear Icon must resolve to #FFFFFF in Dark Mode',
      );

      // ── 3. D3-A Surfaces Preservation ──
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        const Color(0xFF1E1E1E),
        reason: 'Folders Upper Canvas must remain #1E1E1E in Dark Mode',
      );

      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        const Color(0xFF2C2C2C),
        reason:
            'Folders Rounded Content Sheet must remain #2C2C2C in Dark Mode',
      );

      final containerWidget = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
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
        reason:
            'Folders Active Search Header Back Arrow must remain #1C1C1E in Light Mode',
      );

      // 2b. Entered search text style remains #1C1C1E
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(
        textField.style?.color,
        const Color(0xFF1C1C1E),
        reason:
            'Folders Search Input entered text color must remain #1C1C1E in Light Mode',
      );

      // 2c. Search hint / placeholder remains #8C8987
      expect(
        textField.decoration?.hintStyle?.color,
        const Color(0xFF8C8987),
        reason:
            'Folders Search Hint / Placeholder must remain #8C8987 in Light Mode',
      );

      // 2d. Close / clear icon remains #1C1C1E
      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsOneWidget);
      final closeIcon = tester.widget<Icon>(closeIconFinder);
      expect(
        closeIcon.color,
        const Color(0xFF1C1C1E),
        reason:
            'Folders Header Close/Clear Icon must remain #1C1C1E in Light Mode',
      );

      // ── 3. D3-A Surfaces Preservation in Light Mode ──
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        AppColors.background,
        reason:
            'Folders Upper Canvas must remain AppColors.background in Light Mode',
      );

      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(
        surface.color,
        Colors.white,
        reason:
            'Folders Rounded Content Sheet must remain Colors.white in Light Mode',
      );
    });
  });

  group('Phase D3-C — Folders Screen Folder Card System Dark Mode Verification',
      () {
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
      final badgeContainerFinder = find
          .ancestor(
            of: find.text('12'),
            matching: find.byType(Container),
          )
          .first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final badgeDec = badgeContainer.decoration as BoxDecoration;
      expect(
        badgeDec.color,
        const Color(0xFF5A5A5A),
        reason:
            'Badge container background must resolve to #5A5A5A in Dark Mode',
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
        reason:
            'FolderFgPainter color must strictly match folder.colorHex in Dark Mode',
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
        reason:
            'FolderBgPainter color must remain _darken(colorHex) in Dark Mode',
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
        reason:
            'DecorativeNoteCard paper must remain Colors.white in Dark Mode',
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
        reason:
            'DecorativeNoteCard must have 5 ruled lines with #E2E2DF in Dark Mode',
      );

      // 8. Customize button remains background #FFFFFF and icon #8E8E93
      final customizeContainerFinder = find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(Container),
          )
          .first;
      final customizeContainer =
          tester.widget<Container>(customizeContainerFinder);
      final customizeDec = customizeContainer.decoration as BoxDecoration;
      expect(
        customizeDec.color,
        Colors.white,
        reason:
            'Customize button background must remain Colors.white in Dark Mode',
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
      final badgeContainerFinder = find
          .ancestor(
            of: find.text('7'),
            matching: find.byType(Container),
          )
          .first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final badgeDec = badgeContainer.decoration as BoxDecoration;
      expect(
        badgeDec.color,
        const Color(0x1A787880),
        reason:
            'Badge container background must remain #1A787880 in Light Mode',
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
        reason:
            'Unhighlighted remainder TextSpan must remain #1C1C1E in Light Mode',
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
      final badgeContainerFinder = find
          .ancestor(
            of: find.text('3'),
            matching: find.byType(Container),
          )
          .first;
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

  group('Phase D3-D — Folders Screen Empty-State Verification', () {
    testWidgets(
        'Dark Mode: Heading resolves to #FFFFFF, subtitle resolves to #757575, CTA text resolves to #FFFFFF, artwork remains invariant',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      // 1. Verify Empty state renders when folders.isEmpty == true
      expect(find.text("Your Folders are Empty"), findsOneWidget);

      // 2. Heading resolves to #FFFFFF
      final heading = tester.widget<Text>(find.text("Your Folders are Empty"));
      expect(
        heading.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Empty state heading must resolve to #FFFFFF in Dark Mode',
      );
      expect(heading.style?.fontSize, 22.0);
      expect(heading.style?.fontWeight, FontWeight.bold);
      expect(heading.textAlign, TextAlign.center);

      // 3. Subtitle resolves to #757575
      final subtitle = tester.widget<Text>(find.text(
          "Organize your thoughts and notes in elegant style. Create your first folder to begin."));
      expect(
        subtitle.style?.color,
        const Color(0xFF757575),
        reason: 'Empty state subtitle must resolve to #757575 in Dark Mode',
      );
      expect(subtitle.style?.fontSize, 14.0);
      expect(subtitle.style?.height, 1.5);
      expect(subtitle.textAlign, TextAlign.center);

      // 4. CTA text resolves to #FFFFFF
      final ctaText = tester.widget<Text>(find.text("Create Folder"));
      expect(
        ctaText.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Empty state CTA text must resolve to #FFFFFF in Dark Mode',
      );
      expect(ctaText.style?.fontSize, 15.0);
      expect(ctaText.style?.fontWeight, FontWeight.bold);

      // 5. Physical folder back flap remains #E6E3D2
      final bgPainter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is FolderBgPainter))
          .painter as FolderBgPainter;
      expect(
        bgPainter.color,
        const Color(0xFFE6E3D2),
        reason:
            'Physical folder back flap color must remain #E6E3D2 in Dark Mode',
      );

      // 6. Physical folder front flap remains #F2F2EE
      final fgPainter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is FolderFgPainter))
          .painter as FolderFgPainter;
      expect(
        fgPainter.color,
        const Color(0xFFF2F2EE),
        reason:
            'Physical folder front flap color must remain #F2F2EE in Dark Mode',
      );

      // 7. Decorative paper remains #FFFFFF
      final noteCards = find.byType(DecorativeNoteCard);
      expect(noteCards, findsNWidgets(2));
      final firstCard = noteCards.first;
      final paperContainers = find.descendant(
        of: firstCard,
        matching: find.byType(Container),
      );
      final paperContainer = tester.widget<Container>(paperContainers.first);
      final paperDec = paperContainer.decoration as BoxDecoration;
      expect(
        paperDec.color,
        Colors.white,
        reason: 'Notepad paper must remain white in Dark Mode',
      );

      // 8. Decorative yellow header remains #FFCC00
      final yellowHeaderBoxes = find.descendant(
        of: firstCard,
        matching: find.byType(DecoratedBox),
      );
      bool foundYellowTape = false;
      for (final element in yellowHeaderBoxes.evaluate()) {
        final widget = element.widget as DecoratedBox;
        final dec = widget.decoration as BoxDecoration;
        if (dec.color == const Color(0xFFFFCC00)) {
          foundYellowTape = true;
          break;
        }
      }
      expect(foundYellowTape, isTrue,
          reason: 'Notepad header tape must remain #FFCC00 in Dark Mode');

      // 9. Ruled lines remain #E2E2DF
      final ruledLines = find.descendant(
        of: firstCard,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == const Color(0xFFE2E2DF),
        ),
      );
      expect(ruledLines, findsNWidgets(5),
          reason: 'Stationery paper must have 5 ruled lines of color #E2E2DF');

      // 10. Yellow plus badge remains #FFCC00
      final plusBadgeContainer = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color ==
                  const Color(0xFFFFCC00) &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final plusBadgeDec = plusBadgeContainer.decoration as BoxDecoration;
      expect(
        plusBadgeDec.color,
        const Color(0xFFFFCC00),
        reason: 'Plus badge background must remain #FFCC00 in Dark Mode',
      );

      // 11. Plus icon remains #1C1C1E
      final plusIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(
        plusIcon.color,
        const Color(0xFF1C1C1E),
        reason:
            'Plus badge icon must remain #1C1C1E for contrast against yellow',
      );
      expect(plusIcon.size, 22.0);

      // 12. D3-A surfaces remain: Upper = #1E1E1E, Sheet = #2C2C2C
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E),
          reason: 'Upper Canvas must remain #1E1E1E in Dark Mode');
      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(surface.color, const Color(0xFF2C2C2C),
          reason: 'Content sheet must remain #2C2C2C in Dark Mode');

      // 13. 32px top sheet radii remain unchanged
      final containerWidget = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason: 'Folders Content Sheet top radii must remain 32px in Dark Mode',
      );
    });

    testWidgets(
        'Light Mode: Heading remains #1C1C1E, subtitle remains #8E8E93, CTA remains #1C1C1E, artwork and surfaces unchanged',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: false));
      await tester.pumpAndSettle();

      // 14. Heading remains #1C1C1E
      final heading = tester.widget<Text>(find.text("Your Folders are Empty"));
      expect(
        heading.style?.color,
        const Color(0xFF1C1C1E),
        reason: 'Empty state heading must remain #1C1C1E in Light Mode',
      );

      // 15. Subtitle remains #8E8E93
      final subtitle = tester.widget<Text>(find.text(
          "Organize your thoughts and notes in elegant style. Create your first folder to begin."));
      expect(
        subtitle.style?.color,
        const Color(0xFF8E8E93),
        reason: 'Empty state subtitle must remain #8E8E93 in Light Mode',
      );

      // 16. CTA remains #1C1C1E
      final ctaText = tester.widget<Text>(find.text("Create Folder"));
      expect(
        ctaText.style?.color,
        const Color(0xFF1C1C1E),
        reason: 'Empty state CTA text must remain #1C1C1E in Light Mode',
      );

      // 17. Physical artwork remains unchanged
      final bgPainter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is FolderBgPainter))
          .painter as FolderBgPainter;
      expect(bgPainter.color, const Color(0xFFE6E3D2));

      final fgPainter = tester
          .widget<CustomPaint>(find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is FolderFgPainter))
          .painter as FolderFgPainter;
      expect(fgPainter.color, const Color(0xFFF2F2EE));

      // 18. Plus badge remains #FFCC00
      final plusBadgeContainer = tester.widget<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color ==
                  const Color(0xFFFFCC00) &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final plusBadgeDec = plusBadgeContainer.decoration as BoxDecoration;
      expect(plusBadgeDec.color, const Color(0xFFFFCC00));

      // 19. Plus icon remains #1C1C1E
      final plusIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(plusIcon.color, const Color(0xFF1C1C1E));

      // 20. D3-A surfaces remain unchanged
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
      final surface = tester
          .widget<PrimaryScreenSurface>(find.byType(PrimaryScreenSurface));
      expect(surface.color, Colors.white);
    });

    testWidgets(
        'CTA Action: Tapping Create Folder triggers showCreateFolderDialog',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      expect(find.text("New Folder"), findsNothing);

      await tester.tap(find.text("Create Folder"));
      await tester.pumpAndSettle();

      expect(find.text("New Folder"), findsOneWidget,
          reason: 'Tapping Create Folder must open the folder creation dialog');
    });

    testWidgets('Geometry Regression: Dimensions and spacing remain intact',
        (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      // 1. Illustration container is 180 × 180
      final illustrationBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 180.0 && w.height == 180.0,
        ),
      );
      expect(illustrationBox.width, 180.0);
      expect(illustrationBox.height, 180.0);

      // 2. Illustration to heading spacing: 24px
      final spacing24 = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 24.0,
      );
      expect(spacing24, findsOneWidget);

      // 3. Heading to subtitle spacing: 10px
      final spacing10 = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 10.0,
      );
      expect(spacing10, findsOneWidget);

      // 4. Subtitle to CTA spacing: 32px
      final spacing32 = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 32.0,
      );
      expect(spacing32, findsOneWidget);

      // 5. CTA surface is 200 × 50 with 25px radius
      final glassSurface = tester.widget<BottomBarGlassSurface>(
        find
            .ancestor(
              of: find.text("Create Folder"),
              matching: find.byType(BottomBarGlassSurface),
            )
            .first,
      );
      expect(glassSurface.width, 200.0);
      expect(glassSurface.height, 50.0);
      expect(glassSurface.borderRadius, BorderRadius.circular(25.0));
      expect(glassSurface.useFrost, isTrue);

      // 6. TactileButton compression scale is 0.9 and Apple Spring is true
      final tactileButton = tester.widget<TactileButton>(
        find
            .ancestor(
              of: find.text("Create Folder"),
              matching: find.byType(TactileButton),
            )
            .first,
      );
      expect(tactileButton.compressionScale, 0.9);
      expect(tactileButton.useAppleSpring, isTrue);
      expect(tactileButton.playSelectionHaptic, isTrue);

      // 7. Outer horizontal padding is 40.0
      final outerPadding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text("Your Folders are Empty"),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        outerPadding.padding,
        const EdgeInsets.symmetric(horizontal: 40.0),
      );
    });
  });

  group('Phase D3-E — Folders Search Empty State Verification', () {
    testWidgets('Test A: Search Empty-State Visibility when query has no matches',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_work',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Initially, folder card is visible
      expect(find.byType(FolderGridCard), findsOneWidget);
      expect(find.text("No folders match search"), findsNothing);

      // Expand search and enter an unmatched query
      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'xyz_nonexistent_folder_123');
      await tester.pumpAndSettle();

      // Search empty state renders
      expect(find.text("No folders match search"), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.byType(FolderGridCard), findsNothing);
    });

    testWidgets('Test B: Dark Mode Palette for Search Empty State',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_work',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'xyz_nonexistent_folder_123');
      await tester.pumpAndSettle();

      // 1. Verify Icon color in Dark Mode is Color(0xFFFFFFFF).withValues(alpha: 0.3)
      final iconFinder = find.byIcon(Icons.folder_open_rounded);
      expect(iconFinder, findsOneWidget);
      final darkIcon = tester.widget<Icon>(iconFinder);
      expect(
        darkIcon.color,
        const Color(0xFFFFFFFF).withValues(alpha: 0.3),
        reason:
            'Folders search empty icon must be Color(0xFFFFFFFF).withValues(alpha: 0.3) in Dark Mode',
      );
      expect(darkIcon.size, 48.0);

      // 2. Verify Text color in Dark Mode is Color(0xFFFFFFFF).withValues(alpha: 0.7)
      final textFinder = find.text("No folders match search");
      expect(textFinder, findsOneWidget);
      final darkText = tester.widget<Text>(textFinder);
      expect(
        darkText.style?.color,
        const Color(0xFFFFFFFF).withValues(alpha: 0.7),
        reason:
            '"No folders match search" text must be Color(0xFFFFFFFF).withValues(alpha: 0.7) in Dark Mode',
      );
      expect(darkText.style?.fontSize, 18.0);
      expect(darkText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('Test C: Light Mode Regression for Search Empty State',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_work',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: false,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'xyz_nonexistent_folder_123');
      await tester.pumpAndSettle();

      // 1. Verify Icon color in Light Mode remains Color(0xFF1C1C1E).withValues(alpha: 0.3)
      final iconFinder = find.byIcon(Icons.folder_open_rounded);
      expect(iconFinder, findsOneWidget);
      final lightIcon = tester.widget<Icon>(iconFinder);
      expect(
        lightIcon.color,
        const Color(0xFF1C1C1E).withValues(alpha: 0.3),
        reason:
            'Folders search empty icon must remain Color(0xFF1C1C1E).withValues(alpha: 0.3) in Light Mode',
      );
      expect(lightIcon.size, 48.0);

      // 2. Verify Text color in Light Mode remains Color(0xFF1C1C1E).withValues(alpha: 0.5)
      final textFinder = find.text("No folders match search");
      expect(textFinder, findsOneWidget);
      final lightText = tester.widget<Text>(textFinder);
      expect(
        lightText.style?.color,
        const Color(0xFF1C1C1E).withValues(alpha: 0.5),
        reason:
            '"No folders match search" text must remain Color(0xFF1C1C1E).withValues(alpha: 0.5) in Light Mode',
      );
      expect(lightText.style?.fontSize, 18.0);
      expect(lightText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets(
        'Test D: Search Recovery (unmatched -> matching -> cleared query)',
        (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_work',
        name: 'Work Projects',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.setSearchExpandedForTesting(true);
      await tester.pumpAndSettle();

      // Step 1: Unmatched query -> search-empty state
      await tester.enterText(
          find.byType(TextField), 'xyz_unmatched');
      await tester.pumpAndSettle();

      expect(find.text("No folders match search"), findsOneWidget);
      expect(find.byType(FolderGridCard), findsNothing);

      // Step 2: Modify query to match -> FolderGridCard returns
      await tester.enterText(find.byType(TextField), 'Work');
      await tester.pumpAndSettle();

      expect(find.text("No folders match search"), findsNothing);
      expect(find.byType(FolderGridCard), findsOneWidget);

      // Step 3: Clear query -> normal folder grid returns
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text("No folders match search"), findsNothing);
      expect(find.byType(FolderGridCard), findsOneWidget);
    });
  });

  group('Phase D3-F1 — Folders Create, Delete, and Context Menu Modals', () {
    testWidgets('Test 1: Dark Mode Create Folder Dialog Palette', (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: true));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.showCreateFolderDialog();
      await tester.pumpAndSettle();

      // 1. Dialog background is #2C2C2C
      final dialogContainerFinder = find.ancestor(
        of: find.text("New Folder"),
        matching: find.byType(Container),
      ).first;
      final dialogContainer = tester.widget<Container>(dialogContainerFinder);
      final decoration = dialogContainer.decoration as BoxDecoration;
      expect(
        decoration.color,
        const Color(0xFF2C2C2C),
        reason: 'Create dialog background must be #2C2C2C in Dark Mode',
      );

      // 2. Title is #FFFFFF
      final titleText = tester.widget<Text>(find.text("New Folder"));
      expect(
        titleText.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Title must be #FFFFFF in Dark Mode',
      );

      // 3. Subtitle is #757575
      final subText = tester.widget<Text>(find.text("Enter a name for this folder"));
      expect(
        subText.style?.color,
        const Color(0xFF757575),
        reason: 'Subtitle must be #757575 in Dark Mode',
      );

      // 4. Input container is #1E1E1E
      final inputContainerFinder = find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(Container),
      ).first;
      final inputContainer = tester.widget<Container>(inputContainerFinder);
      final inputDec = inputContainer.decoration as BoxDecoration;
      expect(
        inputDec.color,
        const Color(0xFF1E1E1E),
        reason: 'Input container background must be #1E1E1E in Dark Mode',
      );

      // 5. Entered text is #FFFFFF & hint is #757575
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Input text style color must be #FFFFFF in Dark Mode',
      );
      expect(
        tf.decoration?.hintStyle?.color,
        const Color(0xFF757575),
        reason: 'Input hint color must be #757575 in Dark Mode',
      );

      // 6. Enter text to inspect clear icon
      await tester.enterText(find.byType(TextField), "Test Name");
      await tester.pumpAndSettle();

      final clearIcon = tester.widget<Icon>(find.byIcon(Icons.cancel));
      expect(
        clearIcon.color,
        const Color(0xFF757575),
        reason: 'Clear icon must be #757575 in Dark Mode',
      );

      // 7. Divider is #3A3A3C
      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsOneWidget);
      final divider = tester.widget<Divider>(dividerFinder);
      expect(
        divider.color,
        const Color(0xFF3A3A3C),
        reason: 'Divider must be #3A3A3C in Dark Mode',
      );

      // 8. Cancel text is #757575
      final cancelText = tester.widget<Text>(find.text("cancel"));
      expect(
        cancelText.style?.color,
        const Color(0xFF757575),
        reason: 'Cancel button text must be #757575 in Dark Mode',
      );

      // 9. Save text is #FFCC00
      final saveText = tester.widget<Text>(find.text("save"));
      expect(
        saveText.style?.color,
        const Color(0xFFFFCC00),
        reason: 'Save button text must be #FFCC00 (theme invariant)',
      );
    });

    testWidgets('Test 2: Light Mode Create Folder Dialog Regression', (tester) async {
      await tester.pumpWidget(buildFoldersScreenHarness(isDark: false));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.showCreateFolderDialog();
      await tester.pumpAndSettle();

      // 1. Dialog background is #FDFDFD
      final dialogContainerFinder = find.ancestor(
        of: find.text("New Folder"),
        matching: find.byType(Container),
      ).first;
      final dialogContainer = tester.widget<Container>(dialogContainerFinder);
      final decoration = dialogContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFDFDFD));

      // 2. Title is #1D1D1D
      final titleText = tester.widget<Text>(find.text("New Folder"));
      expect(titleText.style?.color, const Color(0xFF1D1D1D));

      // 3. Subtitle is #8E8E93
      final subText = tester.widget<Text>(find.text("Enter a name for this folder"));
      expect(subText.style?.color, const Color(0xFF8E8E93));

      // 4. Input container is #EFEFF4
      final inputContainerFinder = find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(Container),
      ).first;
      final inputContainer = tester.widget<Container>(inputContainerFinder);
      final inputDec = inputContainer.decoration as BoxDecoration;
      expect(inputDec.color, const Color(0xFFEFEFF4));

      // 5. Entered text is #1C1C1E & hint is #AEAEB2
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.style?.color, const Color(0xFF1C1C1E));
      expect(tf.decoration?.hintStyle?.color, const Color(0xFFAEAEB2));

      // 6. Enter text to inspect clear icon
      await tester.enterText(find.byType(TextField), "Test Name");
      await tester.pumpAndSettle();

      final clearIcon = tester.widget<Icon>(find.byIcon(Icons.cancel));
      expect(clearIcon.color, const Color(0xFFC7C7CC));

      // 7. Divider is #D1D1D6
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.color, const Color(0xFFD1D1D6));

      // 8. Cancel text is #8E8E93
      final cancelText = tester.widget<Text>(find.text("cancel"));
      expect(cancelText.style?.color, const Color(0xFF8E8E93));

      // 9. Save text is #FFCC00
      final saveText = tester.widget<Text>(find.text("save"));
      expect(saveText.style?.color, const Color(0xFFFFCC00));
    });

    testWidgets('Test 3: Create Folder Dialog Interaction Flow', (tester) async {
      final notesProvider = _TestNotesProvider();
      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      final state = tester.state<FolderManagementScreenState>(
          find.byType(FolderManagementScreen));
      state.showCreateFolderDialog();
      await tester.pumpAndSettle();

      // Empty text -> tap save -> does not create folder, dialog remains open
      await tester.tap(find.text("save"));
      await tester.pumpAndSettle();
      expect(find.text("New Folder"), findsOneWidget);
      expect(notesProvider.folders, isEmpty);

      // Cancel button dismisses
      await tester.tap(find.text("cancel"));
      await tester.pumpAndSettle();
      expect(find.text("New Folder"), findsNothing);

      // Re-open, enter text, tap save -> creates folder and dismisses
      state.showCreateFolderDialog();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "Projects");
      await tester.pumpAndSettle();

      await tester.tap(find.text("save"));
      await tester.pumpAndSettle();

      expect(find.text("New Folder"), findsNothing);
      expect(notesProvider.folders.length, 1);
      expect(notesProvider.folders.first.name, "Projects");
    });

    testWidgets('Test 4: Dark Mode Folder Context Menu Palette', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_test',
        name: 'Work',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Long-press folder card to open context menu
      await tester.longPress(find.byType(FolderGridCard).first);
      await tester.pumpAndSettle();

      expect(find.text("Customize"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);

      // 1. Context Menu Surface is #2C2C2C
      final menuMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.text("Customize"),
          matching: find.byType(Material),
        ).first,
      );
      expect(
        menuMaterial.color,
        const Color(0xFF2C2C2C),
        reason: 'Context menu surface must be #2C2C2C in Dark Mode',
      );

      // 2. Customize text is #FFFFFF & icon is #FFFFFF
      final customizeText = tester.widget<Text>(find.text("Customize"));
      expect(
        customizeText.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Customize text must be #FFFFFF in Dark Mode',
      );
      final customizeIcon = tester.widget<Icon>(find.byIcon(Icons.color_lens_outlined));
      expect(
        customizeIcon.color,
        const Color(0xFFFFFFFF),
        reason: 'Customize icon must be #FFFFFF in Dark Mode',
      );

      // 3. Menu Divider is #3A3A3C
      final menuDivider = tester.widget<Divider>(find.byType(Divider));
      expect(
        menuDivider.color,
        const Color(0xFF3A3A3C),
        reason: 'Context menu divider must be #3A3A3C in Dark Mode',
      );

      // 4. Delete text is #FF453A & icon is #FF453A
      final deleteText = tester.widget<Text>(find.text("Delete"));
      expect(
        deleteText.style?.color,
        const Color(0xFFFF453A),
        reason: 'Delete text must be #FF453A in Dark Mode',
      );
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded));
      expect(
        deleteIcon.color,
        const Color(0xFFFF453A),
        reason: 'Delete icon must be #FF453A in Dark Mode',
      );

      // Outside tap dismisses
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text("Customize"), findsNothing);
    });

    testWidgets('Test 5: Light Mode Folder Context Menu Regression', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_test',
        name: 'Work',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: false,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(FolderGridCard).first);
      await tester.pumpAndSettle();

      // 1. Surface is #F2F2EE
      final menuMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.text("Customize"),
          matching: find.byType(Material),
        ).first,
      );
      expect(menuMaterial.color, const Color(0xFFF2F2EE));

      // 2. Customize text is #1C1C1E & icon is #1C1C1E
      final customizeText = tester.widget<Text>(find.text("Customize"));
      expect(customizeText.style?.color, const Color(0xFF1C1C1E));
      final customizeIcon = tester.widget<Icon>(find.byIcon(Icons.color_lens_outlined));
      expect(customizeIcon.color, const Color(0xFF1C1C1E));

      // 3. Menu Divider is #D1D1D6
      final menuDivider = tester.widget<Divider>(find.byType(Divider));
      expect(menuDivider.color, const Color(0xFFD1D1D6));

      // 4. Delete text is Colors.red & icon is Colors.red
      final deleteText = tester.widget<Text>(find.text("Delete"));
      expect(deleteText.style?.color, Colors.red);
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded));
      expect(deleteIcon.color, Colors.red);
    });

    testWidgets('Test 6: Dark Mode Delete Confirmation Dialog Palette & Interaction', (tester) async {
      final notesProvider = _TestNotesProvider();
      final folder = Folder(
        id: 'f_delete',
        name: 'Target Folder',
        createdAt: DateTime.now(),
      );
      notesProvider.addTestFolder(folder);

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: true,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      // Open context menu and tap Delete
      await tester.longPress(find.byType(FolderGridCard).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      // Verify AlertDialog is visible
      expect(find.byType(AlertDialog), findsOneWidget);
      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));

      // 1. Dialog background is #2C2C2C
      expect(
        alertDialog.backgroundColor,
        const Color(0xFF2C2C2C),
        reason: 'Delete dialog surface must be #2C2C2C in Dark Mode',
      );

      // 2. Title is #FFFFFF
      final titleText = tester.widget<Text>(find.text("Delete Folder?"));
      expect(
        titleText.style?.color,
        const Color(0xFFFFFFFF),
        reason: 'Delete dialog title must be #FFFFFF in Dark Mode',
      );

      // 3. Body text is #FFFFFF @ 70%
      final bodyText = tester.widget<Text>(
        find.textContaining("Internal notes will be moved to the root level"),
      );
      expect(
        bodyText.style?.color,
        const Color(0xFFFFFFFF).withValues(alpha: 0.70),
        reason: 'Delete dialog body text must be #FFFFFF @ 70% in Dark Mode',
      );

      // 4. Cancel text is #757575
      final cancelText = tester.widget<Text>(find.text("Cancel"));
      expect(
        cancelText.style?.color,
        const Color(0xFF757575),
        reason: 'Cancel button text must be #757575 in Dark Mode',
      );

      // 5. Delete button text is #FF453A
      final deleteBtn = tester.widget<TextButton>(find.widgetWithText(TextButton, "Delete"));
      expect(
        deleteBtn.style?.foregroundColor?.resolve({}),
        const Color(0xFFFF453A),
        reason: 'Delete button foregroundColor must be #FF453A in Dark Mode',
      );

      // 6. Test Cancel dismisses without deleting
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(notesProvider.folders.length, 1);

      // 7. Re-open and confirm Delete deletes the folder
      await tester.longPress(find.byType(FolderGridCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, "Delete"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(notesProvider.folders, isEmpty);
    });

    testWidgets('Test 7: Light Mode Delete Confirmation Dialog Regression', (tester) async {
      final notesProvider = _TestNotesProvider();
      notesProvider.addTestFolder(Folder(
        id: 'f_delete',
        name: 'Target Folder',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(buildFoldersScreenHarness(
        isDark: false,
        notesProvider: notesProvider,
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(FolderGridCard).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Delete"));
      await tester.pumpAndSettle();

      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));

      // 1. Dialog background is Colors.white
      expect(alertDialog.backgroundColor, Colors.white);

      // 2. Title is #1C1C1E
      final titleText = tester.widget<Text>(find.text("Delete Folder?"));
      expect(titleText.style?.color, const Color(0xFF1C1C1E));

      // 3. Body text is #1C1C1E @ 80%
      final bodyText = tester.widget<Text>(
        find.textContaining("Internal notes will be moved to the root level"),
      );
      expect(bodyText.style?.color, const Color(0xFF1C1C1E).withValues(alpha: 0.8));

      // 4. Cancel text is #8C8987
      final cancelText = tester.widget<Text>(find.text("Cancel"));
      expect(cancelText.style?.color, const Color(0xFF8C8987));

      // 5. Delete button text uses theme.colorScheme.error
      final deleteBtn = tester.widget<TextButton>(find.widgetWithText(TextButton, "Delete"));
      expect(
        deleteBtn.style?.foregroundColor?.resolve({}),
        ThemeData.light().colorScheme.error,
      );
    });

    testWidgets('Test 8: Standalone DeleteConfirmationDialog Dark Mode Parity & Light Mode Regression', (tester) async {
      // 1. Dark Mode
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: DeleteConfirmationDialog(
            title: 'Delete Note',
            message: 'Are you sure you want to delete\nthis note?',
            cancelText: 'Cancel',
            deleteText: 'Delete',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Card container is #2C2C2C
      final darkContainerFinder = find.ancestor(
        of: find.text("Delete Note"),
        matching: find.byType(Container),
      ).first;
      final darkContainer = tester.widget<Container>(darkContainerFinder);
      final darkShape = darkContainer.decoration as ShapeDecoration;
      expect(darkShape.color, const Color(0xFF2C2C2C));

      // Title is #FFFFFF
      final darkTitle = tester.widget<Text>(find.text("Delete Note"));
      expect(darkTitle.style?.color, const Color(0xFFFFFFFF));

      // Message is #FFFFFF @ 70%
      final darkMsg = tester.widget<Text>(find.text("Are you sure you want to delete\nthis note?"));
      expect(darkMsg.style?.color, const Color(0xFFFFFFFF).withValues(alpha: 0.70));

      // Cancel is #757575
      final darkCancel = tester.widget<Text>(find.text("Cancel"));
      expect(darkCancel.style?.color, const Color(0xFF757575));

      // Delete is #FF453A
      final darkDelete = tester.widget<Text>(find.text("Delete"));
      expect(darkDelete.style?.color, const Color(0xFFFF453A));

      // 2. Light Mode Regression
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: DeleteConfirmationDialog(
            title: 'Delete Note',
            message: 'Are you sure you want to delete\nthis note?',
            cancelText: 'Cancel',
            deleteText: 'Delete',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final lightContainerFinder = find.ancestor(
        of: find.text("Delete Note"),
        matching: find.byType(Container),
      ).first;
      final lightContainer = tester.widget<Container>(lightContainerFinder);
      final lightShape = lightContainer.decoration as ShapeDecoration;
      expect(lightShape.color, Colors.white);

      final lightTitle = tester.widget<Text>(find.text("Delete Note"));
      expect(lightTitle.style?.color, const Color(0xFF333333));

      final lightMsg = tester.widget<Text>(find.text("Are you sure you want to delete\nthis note?"));
      expect(lightMsg.style?.color, const Color(0xFF333333));

      final lightCancel = tester.widget<Text>(find.text("Cancel"));
      expect(lightCancel.style?.color, const Color(0xFF333333));

      final lightDelete = tester.widget<Text>(find.text("Delete"));
      expect(lightDelete.style?.color, const Color(0xFFFF383C));
    });
  });

  group('Phase D3-F2 — Folder Customization Sheet & Sticker UI Dark Mode Verification', () {
    Widget buildCustomizationSheetHarness({
      required bool isDark,
      Folder? folder,
      ValueChanged<Folder>? onApply,
    }) {
      final testFolder = folder ??
          Folder(
            id: 'f_custom_test',
            name: 'Test Folder',
            colorHex: '0xFFB0B0A8',
            sticker: 'birds.png',
            createdAt: DateTime.now(),
          );
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: FolderCustomizationSheet(
            folder: testFolder,
            onApply: onApply ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('Test 1 — Dark Customization Sheet Palette', (tester) async {
      await tester.pumpWidget(buildCustomizationSheetHarness(isDark: true));
      await tester.pumpAndSettle();

      // 1. Sheet surface is #2C2C2C
      final sheetContainerFinder = find.ancestor(
        of: find.text("Customize Folder"),
        matching: find.byType(Container),
      ).first;
      final sheetContainer = tester.widget<Container>(sheetContainerFinder);
      final sheetDec = sheetContainer.decoration as BoxDecoration;
      expect(sheetDec.color, const Color(0xFF2C2C2C),
          reason: 'Customization sheet surface must be #2C2C2C in Dark Mode');

      // 2. Drag handle is #5A5A5A
      final handleFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final dec = widget.decoration as BoxDecoration;
          return widget.constraints?.maxWidth == 36.0 &&
              widget.constraints?.maxHeight == 5.0 &&
              dec.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget,
          reason: 'Drag handle must be #5A5A5A in Dark Mode');

      // 3. Title is #FFFFFF
      final title = tester.widget<Text>(find.text("Customize Folder"));
      expect(title.style?.color, const Color(0xFFFFFFFF),
          reason: 'Sheet title must be #FFFFFF in Dark Mode');

      // 4. Section titles are #FFFFFF
      final colorTitle = tester.widget<Text>(find.text("Folder Color"));
      expect(colorTitle.style?.color, const Color(0xFFFFFFFF),
          reason: 'Folder Color section title must be #FFFFFF in Dark Mode');

      final stickerTitle = tester.widget<Text>(find.text("Sticker Store"));
      expect(stickerTitle.style?.color, const Color(0xFFFFFFFF),
          reason: 'Sticker section title must be #FFFFFF in Dark Mode');

      // 5. Eyedropper bg is #3A3A3C and icon is #FFFFFF
      final eyedropperContainerFinder = find.ancestor(
        of: find.byIcon(Icons.colorize_rounded),
        matching: find.byType(Container),
      ).first;
      final eyedropperContainer =
          tester.widget<Container>(eyedropperContainerFinder);
      final eyeDec = eyedropperContainer.decoration as BoxDecoration;
      expect(eyeDec.color, const Color(0xFF3A3A3C),
          reason: 'Eyedropper background must be #3A3A3C in Dark Mode');

      final eyeIcon =
          tester.widget<Icon>(find.byIcon(Icons.colorize_rounded));
      expect(eyeIcon.color, const Color(0xFFFFFFFF),
          reason: 'Eyedropper icon must be #FFFFFF in Dark Mode');

      // 6. Selected color border is #FFFFFF
      final selectedColorCheck = find.byIcon(Icons.check);
      expect(selectedColorCheck, findsWidgets);
      final selectedSwatchContainerFinder = find.ancestor(
        of: selectedColorCheck.first,
        matching: find.byType(Container),
      ).first;
      final selectedSwatch =
          tester.widget<Container>(selectedSwatchContainerFinder);
      final swatchDec = selectedSwatch.decoration as BoxDecoration;
      expect(swatchDec.border?.top.color, const Color(0xFFFFFFFF),
          reason: 'Selected color border must be #FFFFFF in Dark Mode');
      final swatchCheckIcon = tester.widget<Icon>(selectedColorCheck.first);
      expect(swatchCheckIcon.color, const Color(0xFFFFFFFF),
          reason: 'Selected color check icon must be #FFFFFF in Dark Mode');
    });

    testWidgets('Test 2 — Light Customization Sheet Regression', (tester) async {
      await tester.pumpWidget(buildCustomizationSheetHarness(isDark: false));
      await tester.pumpAndSettle();

      // 1. Sheet surface is #F9F9F7
      final sheetContainerFinder = find.ancestor(
        of: find.text("Customize Folder"),
        matching: find.byType(Container),
      ).first;
      final sheetContainer = tester.widget<Container>(sheetContainerFinder);
      final sheetDec = sheetContainer.decoration as BoxDecoration;
      expect(sheetDec.color, const Color(0xFFF9F9F7),
          reason: 'Customization sheet surface must be #F9F9F7 in Light Mode');

      // 2. Drag handle is #D1D1D6
      final handleFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final dec = widget.decoration as BoxDecoration;
          return widget.constraints?.maxWidth == 36.0 &&
              widget.constraints?.maxHeight == 5.0 &&
              dec.color == const Color(0xFFD1D1D6);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget,
          reason: 'Drag handle must be #D1D1D6 in Light Mode');

      // 3. Title is #1C1C1E
      final title = tester.widget<Text>(find.text("Customize Folder"));
      expect(title.style?.color, const Color(0xFF1C1C1E),
          reason: 'Sheet title must be #1C1C1E in Light Mode');

      // 4. Section titles are #1C1C1E
      final colorTitle = tester.widget<Text>(find.text("Folder Color"));
      expect(colorTitle.style?.color, const Color(0xFF1C1C1E),
          reason: 'Folder Color section title must be #1C1C1E in Light Mode');

      final stickerTitle = tester.widget<Text>(find.text("Sticker Store"));
      expect(stickerTitle.style?.color, const Color(0xFF1C1C1E),
          reason: 'Sticker section title must be #1C1C1E in Light Mode');

      // 5. Eyedropper bg is #EFEFF4 and icon is #1C1C1E
      final eyedropperContainerFinder = find.ancestor(
        of: find.byIcon(Icons.colorize_rounded),
        matching: find.byType(Container),
      ).first;
      final eyedropperContainer =
          tester.widget<Container>(eyedropperContainerFinder);
      final eyeDec = eyedropperContainer.decoration as BoxDecoration;
      expect(eyeDec.color, const Color(0xFFEFEFF4),
          reason: 'Eyedropper background must be #EFEFF4 in Light Mode');

      final eyeIcon =
          tester.widget<Icon>(find.byIcon(Icons.colorize_rounded));
      expect(eyeIcon.color, const Color(0xFF1C1C1E),
          reason: 'Eyedropper icon must be #1C1C1E in Light Mode');

      // 6. Selected color border is #1C1C1E
      final selectedColorCheck = find.byIcon(Icons.check);
      final selectedSwatchContainerFinder = find.ancestor(
        of: selectedColorCheck.first,
        matching: find.byType(Container),
      ).first;
      final selectedSwatch =
          tester.widget<Container>(selectedSwatchContainerFinder);
      final swatchDec = selectedSwatch.decoration as BoxDecoration;
      expect(swatchDec.border?.top.color, const Color(0xFF1C1C1E),
          reason: 'Selected color border must be #1C1C1E in Light Mode');
      final swatchCheckIcon = tester.widget<Icon>(selectedColorCheck.first);
      expect(swatchCheckIcon.color, const Color(0xFF1C1C1E),
          reason: 'Selected color check icon must be #1C1C1E in Light Mode');
    });

    testWidgets('Test 3 — Dark Sticker UI Palette', (tester) async {
      await tester.pumpWidget(buildCustomizationSheetHarness(
        isDark: true,
        folder: Folder(
          id: 'f_test',
          name: 'Sticker Test',
          colorHex: '0xFFB0B0A8',
          sticker: 'birds.png',
          createdAt: DateTime.now(),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Sticker section title is #FFFFFF
      final stickerTitle = tester.widget<Text>(find.text("Sticker Store"));
      expect(stickerTitle.style?.color, const Color(0xFFFFFFFF));

      // 2. None background is #3A3A3C and icon is #757575
      final noneContainerFinder = find.ancestor(
        of: find.byIcon(Icons.block_rounded),
        matching: find.byType(Container),
      ).first;
      final noneContainer = tester.widget<Container>(noneContainerFinder);
      final noneDec = noneContainer.decoration as BoxDecoration;
      expect(noneDec.color, const Color(0xFF3A3A3C),
          reason: 'None background must be #3A3A3C in Dark Mode');

      final noneIcon = tester.widget<Icon>(find.byIcon(Icons.block_rounded));
      expect(noneIcon.color, const Color(0xFF757575),
          reason: 'None icon must be #757575 in Dark Mode');

      // 3. Sticker card is #2C2C2C
      final stickerImageFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == "assets/stickers/birds.png");
      expect(stickerImageFinder, findsOneWidget);

      final stickerCardFinder = find.ancestor(
        of: stickerImageFinder,
        matching: find.byType(Container),
      ).first;
      final stickerCard = tester.widget<Container>(stickerCardFinder);
      final stickerDec = stickerCard.decoration as BoxDecoration;
      expect(stickerDec.color, const Color(0xFF2C2C2C),
          reason: 'Sticker card background must be #2C2C2C in Dark Mode');

      // 4. Selected border is #FFFFFF
      expect(stickerDec.border?.top.color, const Color(0xFFFFFFFF),
          reason: 'Selected sticker border must be #FFFFFF in Dark Mode');

      // 5. Selected badge is #34C759 and check is #FFFFFF
      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.color == const Color(0xFF34C759) &&
              dec.shape == BoxShape.circle;
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget,
          reason: 'Selected badge must be #34C759');

      final badgeCheckIcon = find.descendant(
        of: badgeContainerFinder,
        matching: find.byIcon(Icons.check),
      );
      expect(badgeCheckIcon, findsOneWidget);
      final checkIcon = tester.widget<Icon>(badgeCheckIcon);
      expect(checkIcon.color, const Color(0xFFFFFFFF),
          reason: 'Badge check must be #FFFFFF');

      // 6. Apply text is #FFFFFF
      final applyText =
          tester.widget<Text>(find.text("Apply Customization"));
      expect(applyText.style?.color, const Color(0xFFFFFFFF),
          reason: 'Apply text must be #FFFFFF in Dark Mode');
    });

    testWidgets('Test 4 — Light Sticker UI Regression', (tester) async {
      await tester.pumpWidget(buildCustomizationSheetHarness(
        isDark: false,
        folder: Folder(
          id: 'f_test',
          name: 'Sticker Test',
          colorHex: '0xFFB0B0A8',
          sticker: 'birds.png',
          createdAt: DateTime.now(),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Sticker section title is #1C1C1E
      final stickerTitle = tester.widget<Text>(find.text("Sticker Store"));
      expect(stickerTitle.style?.color, const Color(0xFF1C1C1E));

      // 2. None background is #EFEFF4 and icon is #8E8E93
      final noneContainerFinder = find.ancestor(
        of: find.byIcon(Icons.block_rounded),
        matching: find.byType(Container),
      ).first;
      final noneContainer = tester.widget<Container>(noneContainerFinder);
      final noneDec = noneContainer.decoration as BoxDecoration;
      expect(noneDec.color, const Color(0xFFEFEFF4),
          reason: 'None background must be #EFEFF4 in Light Mode');

      final noneIcon = tester.widget<Icon>(find.byIcon(Icons.block_rounded));
      expect(noneIcon.color, const Color(0xFF8E8E93),
          reason: 'None icon must be #8E8E93 in Light Mode');

      // 3. Sticker card is Colors.white
      final stickerImageFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == "assets/stickers/birds.png");
      expect(stickerImageFinder, findsOneWidget);

      final stickerCardFinder = find.ancestor(
        of: stickerImageFinder,
        matching: find.byType(Container),
      ).first;
      final stickerCard = tester.widget<Container>(stickerCardFinder);
      final stickerDec = stickerCard.decoration as BoxDecoration;
      expect(stickerDec.color, Colors.white,
          reason: 'Sticker card background must be Colors.white in Light Mode');

      // 4. Selected border is #1C1C1E
      expect(stickerDec.border?.top.color, const Color(0xFF1C1C1E),
          reason: 'Selected sticker border must be #1C1C1E in Light Mode');

      // 5. Selected badge is #34C759 and check is #FFFFFF
      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.color == const Color(0xFF34C759) &&
              dec.shape == BoxShape.circle;
        }
        return false;
      });
      expect(badgeContainerFinder, findsOneWidget,
          reason: 'Selected badge must be #34C759');

      final badgeCheckIcon = find.descendant(
        of: badgeContainerFinder,
        matching: find.byIcon(Icons.check),
      );
      expect(badgeCheckIcon, findsOneWidget);
      final checkIcon = tester.widget<Icon>(badgeCheckIcon);
      expect(checkIcon.color, const Color(0xFFFFFFFF),
          reason: 'Badge check must be #FFFFFF');

      // 6. Apply text is #1C1C1E
      final applyText =
          tester.widget<Text>(find.text("Apply Customization"));
      expect(applyText.style?.color, const Color(0xFF1C1C1E),
          reason: 'Apply text must be #1C1C1E in Light Mode');
    });

    testWidgets('Test 5 — Sticker Artwork Invariance', (tester) async {
      await tester.pumpWidget(buildCustomizationSheetHarness(isDark: true));
      await tester.pumpAndSettle();

      final stickerImages = tester.widgetList<Image>(find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.startsWith("assets/stickers/")));

      expect(stickerImages.length, equals(6),
          reason: 'All 6 sticker images must be present');

      for (final img in stickerImages) {
        expect(img.color, isNull,
            reason: 'Sticker asset must not have color tint applied');
        expect(img.colorBlendMode, isNull,
            reason: 'Sticker asset must not have blend mode applied');
      }

      // Verify no ColorFiltered widget wraps sticker image
      final firstStickerImage = find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == "assets/stickers/birds.png");
      final colorFilteredAncestor = find.ancestor(
        of: firstStickerImage,
        matching: find.byType(ColorFiltered),
      );
      expect(colorFilteredAncestor, findsNothing,
          reason: 'Sticker image must not be wrapped in ColorFiltered');
    });

    testWidgets('Test 6 — Color Swatch Invariance', (tester) async {
      // Dark Mode
      await tester.pumpWidget(buildCustomizationSheetHarness(isDark: true));
      await tester.pumpAndSettle();

      final expectedColors = [
        const Color(0xFFB0B0A8),
        const Color(0xFFFFBDE6),
        const Color(0xFFD6C8FF),
        const Color(0xFFA8DADC),
        const Color(0xFFD4ECDD),
        const Color(0xFFFFC6FF),
      ];

      for (final expected in expectedColors) {
        final swatchFinder = find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final dec = w.decoration as BoxDecoration;
            return dec.shape == BoxShape.circle && dec.color == expected;
          }
          return false;
        });
        expect(swatchFinder, findsOneWidget,
            reason: 'Swatch $expected must be present in Dark Mode');
      }

      // Light Mode
      await tester.pumpWidget(buildCustomizationSheetHarness(isDark: false));
      await tester.pumpAndSettle();

      for (final expected in expectedColors) {
        final swatchFinder = find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final dec = w.decoration as BoxDecoration;
            return dec.shape == BoxShape.circle && dec.color == expected;
          }
          return false;
        });
        expect(swatchFinder, findsOneWidget,
            reason: 'Swatch $expected must be present in Light Mode');
      }
    });

    testWidgets('Test 7 — Interaction Regression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Folder? appliedFolder;
      final initialFolder = Folder(
        id: 'f_test_interactive',
        name: 'Interactive Test',
        colorHex: '0xFFB0B0A8',
        sticker: null,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCustomizationSheetHarness(
        isDark: true,
        folder: initialFolder,
        onApply: (f) => appliedFolder = f,
      ));
      await tester.pumpAndSettle();

      // 1. Initial state: Grey is selected, None is selected
      expect(find.byIcon(Icons.check), findsOneWidget); // only on Grey swatch

      // 2. Select Pink swatch (0xFFFFBDE6)
      final pinkSwatch = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.shape == BoxShape.circle && dec.color == const Color(0xFFFFBDE6);
        }
        return false;
      });
      await tester.tap(pinkSwatch);
      await tester.pumpAndSettle();

      // 3. Select first sticker (birds.png)
      final birdsSticker = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == "assets/stickers/birds.png");
      await tester.tap(birdsSticker);
      await tester.pumpAndSettle();

      // Should now have 2 checks: one on Pink swatch, one on sticker badge
      expect(find.byIcon(Icons.check), findsNWidgets(2));

      // 4. Select None sticker
      await tester.tap(find.byIcon(Icons.block_rounded));
      await tester.pumpAndSettle();

      // Badge check is gone, only Pink swatch check remains
      expect(find.byIcon(Icons.check), findsOneWidget);

      // 5. Open custom color picker via eyedropper
      await tester.tap(find.byIcon(Icons.colorize_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(IosColorPickerDialog), findsOneWidget);

      // 6. Dismiss dialog via Navigator pop
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(IosColorPickerDialog), findsNothing);

      // 7. Apply customization
      await tester.tap(find.text("Apply Customization"));
      await tester.pumpAndSettle();

      expect(appliedFolder, isNotNull);
      expect(appliedFolder!.colorHex, equals("0xFFFFBDE6"));
      expect(appliedFolder!.sticker, isNull);
    });

    testWidgets('Test 8 — Premium Regression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testFolder = Folder(
        id: 'f_prem_test',
        name: 'Premium Test',
        createdAt: DateTime.now(),
      );

      // 1. Non-premium user encounters PremiumGateSheet
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FeatureAccess>.value(
              value: _FakeFeatureAccess(allowsCustomization: false),
            ),
            ChangeNotifierProvider<NotesProvider>.value(
              value: NotesProvider(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => openFolderCustomization(ctx, testFolder),
                  child: const Text('Open Non-Premium'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Non-Premium'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsOneWidget,
          reason: 'Non-premium user must encounter PremiumGateSheet');
      expect(find.byType(FolderCustomizationSheet), findsNothing,
          reason: 'Non-premium user must not access FolderCustomizationSheet');

      // Dismiss the bottom sheet so that subsequent tests/widgets are not obscured
      Navigator.of(tester.element(find.byType(PremiumGateSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PremiumGateSheet), findsNothing);

      // 2. Premium user opens FolderCustomizationSheet directly
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FeatureAccess>.value(
              value: _FakeFeatureAccess(allowsCustomization: true),
            ),
            ChangeNotifierProvider<NotesProvider>.value(
              value: NotesProvider(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => openFolderCustomization(ctx, testFolder),
                  child: const Text('Open Premium'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Premium'));
      await tester.pumpAndSettle();

      expect(find.byType(PremiumGateSheet), findsNothing,
          reason: 'Premium user must not see PremiumGateSheet');
      expect(find.byType(FolderCustomizationSheet), findsOneWidget,
          reason: 'Premium user must access FolderCustomizationSheet');
    });
  });

  group('Phase D3-F3 — Color Picker (IosColorPickerDialog) Dark Mode Verification', () {
    Widget buildColorPickerHarness({
      required bool isDark,
      Color initialColor = const Color(0xFF007AFF),
      ValueChanged<Color>? onColorSelected,
    }) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (_) => IosColorPickerDialog(
                    initialColor: initialColor,
                    onColorSelected: onColorSelected ?? (_) {},
                  ),
                );
              },
              child: const Text('Open Color Picker'),
            ),
          ),
        ),
      );
    }

    testWidgets('Test 1 — Dark Mode Dialog Surface & Header', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. Dialog background is #2C2C2C and radius is 28.0
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFF2C2C2C),
          reason: 'Dialog background must be #2C2C2C in Dark Mode');
      final shape = dialog.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(28.0),
          reason: 'Dialog border radius must be 28.0');

      // 2. Header icon is #FFFFFF
      final colorizeIcon =
          tester.widget<Icon>(find.byIcon(Icons.colorize_rounded));
      expect(colorizeIcon.color, const Color(0xFFFFFFFF),
          reason: 'Colorize icon must be #FFFFFF in Dark Mode');

      // 3. Header title "Colors" is #FFFFFF
      final title = tester.widget<Text>(find.text("Colors"));
      expect(title.style?.color, const Color(0xFFFFFFFF),
          reason: 'Title "Colors" must be #FFFFFF in Dark Mode');

      // 4. Header close icon is #FFFFFF
      final closeIcon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(closeIcon.color, const Color(0xFFFFFFFF),
          reason: 'Close icon must be #FFFFFF in Dark Mode');
    });

    testWidgets('Test 2 — Light Mode Dialog Surface & Header Regression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. Dialog background is #F9F9F7
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, const Color(0xFFF9F9F7),
          reason: 'Dialog background must be #F9F9F7 in Light Mode');

      // 2. Header icon is #1C1C1E
      final colorizeIcon =
          tester.widget<Icon>(find.byIcon(Icons.colorize_rounded));
      expect(colorizeIcon.color, const Color(0xFF1C1C1E),
          reason: 'Colorize icon must be #1C1C1E in Light Mode');

      // 3. Header title is #1C1C1E
      final title = tester.widget<Text>(find.text("Colors"));
      expect(title.style?.color, const Color(0xFF1C1C1E),
          reason: 'Title "Colors" must be #1C1C1E in Light Mode');

      // 4. Header close icon is #1C1C1E
      final closeIcon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
      expect(closeIcon.color, const Color(0xFF1C1C1E),
          reason: 'Close icon must be #1C1C1E in Light Mode');
    });

    testWidgets('Test 3 — Dark Mode Tab Selector Palette', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. Tab track is #1E1E1E
      final rowFinder =
          find.ancestor(of: find.text("Grid"), matching: find.byType(Row)).first;
      final trackContainerFinder =
          find.ancestor(of: rowFinder, matching: find.byType(Container)).first;
      final trackContainer = tester.widget<Container>(trackContainerFinder);
      final trackDec = trackContainer.decoration as BoxDecoration;
      expect(trackDec.color, const Color(0xFF1E1E1E),
          reason: 'Tab track must be #1E1E1E in Dark Mode');

      // 2. Active tab ("Grid") pill is #3A3A3C, label is #FFFFFF (w700)
      final gridPill = tester.widget<Container>(find
          .ancestor(of: find.text("Grid"), matching: find.byType(Container))
          .first);
      final gridPillDec = gridPill.decoration as BoxDecoration;
      expect(gridPillDec.color, const Color(0xFF3A3A3C),
          reason: 'Active tab pill must be #3A3A3C in Dark Mode');
      final gridText = tester.widget<Text>(find.text("Grid"));
      expect(gridText.style?.color, const Color(0xFFFFFFFF),
          reason: 'Active tab label must be #FFFFFF in Dark Mode');
      expect(gridText.style?.fontWeight, FontWeight.w700);

      // 3. Inactive labels ("Spectrum", "Sliders") are #757575 (w500)
      final spectrumText = tester.widget<Text>(find.text("Spectrum"));
      expect(spectrumText.style?.color, const Color(0xFF757575),
          reason: 'Inactive tab label must be #757575 in Dark Mode');
      expect(spectrumText.style?.fontWeight, FontWeight.w500);

      final slidersText = tester.widget<Text>(find.text("Sliders"));
      expect(slidersText.style?.color, const Color(0xFF757575),
          reason: 'Inactive tab label must be #757575 in Dark Mode');
      expect(slidersText.style?.fontWeight, FontWeight.w500);

      // 4. Tap "Sliders" -> active switches to #3A3A3C and #FFFFFF
      await tester.tap(find.text("Sliders"));
      await tester.pumpAndSettle();

      final slidersPill = tester.widget<Container>(find
          .ancestor(of: find.text("Sliders"), matching: find.byType(Container))
          .first);
      final slidersPillDec = slidersPill.decoration as BoxDecoration;
      expect(slidersPillDec.color, const Color(0xFF3A3A3C),
          reason: 'Active tab pill must be #3A3A3C after tab switch in Dark Mode');

      final slidersActiveText = tester.widget<Text>(find.text("Sliders"));
      expect(slidersActiveText.style?.color, const Color(0xFFFFFFFF));
      expect(slidersActiveText.style?.fontWeight, FontWeight.w700);

      final gridInactiveText = tester.widget<Text>(find.text("Grid"));
      expect(gridInactiveText.style?.color, const Color(0xFF757575));
      expect(gridInactiveText.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('Test 4 — Light Mode Tab Selector Regression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. Tab track is #EFEFF4
      final rowFinder =
          find.ancestor(of: find.text("Grid"), matching: find.byType(Row)).first;
      final trackContainerFinder =
          find.ancestor(of: rowFinder, matching: find.byType(Container)).first;
      final trackContainer = tester.widget<Container>(trackContainerFinder);
      final trackDec = trackContainer.decoration as BoxDecoration;
      expect(trackDec.color, const Color(0xFFEFEFF4),
          reason: 'Tab track must be #EFEFF4 in Light Mode');

      // 2. Active tab ("Grid") pill is Colors.white, label is #1C1C1E (w700)
      final gridPill = tester.widget<Container>(find
          .ancestor(of: find.text("Grid"), matching: find.byType(Container))
          .first);
      final gridPillDec = gridPill.decoration as BoxDecoration;
      expect(gridPillDec.color, Colors.white,
          reason: 'Active tab pill must be Colors.white in Light Mode');
      final gridText = tester.widget<Text>(find.text("Grid"));
      expect(gridText.style?.color, const Color(0xFF1C1C1E),
          reason: 'Active tab label must be #1C1C1E in Light Mode');
      expect(gridText.style?.fontWeight, FontWeight.w700);

      // 3. Inactive labels are #1C1C1E (w500)
      final spectrumText = tester.widget<Text>(find.text("Spectrum"));
      expect(spectrumText.style?.color, const Color(0xFF1C1C1E),
          reason: 'Inactive tab label must be #1C1C1E in Light Mode');
      expect(spectrumText.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('Test 5 — Dark Mode Opacity & RGB Slider Chrome', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. "OPACITY" label is #757575
      final opacityLabel = tester.widget<Text>(find.text("OPACITY"));
      expect(opacityLabel.style?.color, const Color(0xFF757575),
          reason: '"OPACITY" label must be #757575 in Dark Mode');

      // 2. Opacity value box is #1E1E1E bg, #3A3A3C border, #FFFFFF text
      final opacityBadgeContainer = tester.widget<Container>(find
          .ancestor(of: find.text("100%"), matching: find.byType(Container))
          .first);
      final badgeDec = opacityBadgeContainer.decoration as BoxDecoration;
      expect(badgeDec.color, const Color(0xFF1E1E1E),
          reason: 'Opacity badge background must be #1E1E1E in Dark Mode');
      expect(badgeDec.border?.top.color, const Color(0xFF3A3A3C),
          reason: 'Opacity badge border must be #3A3A3C in Dark Mode');
      final opacityText = tester.widget<Text>(find.text("100%"));
      expect(opacityText.style?.color, const Color(0xFFFFFFFF),
          reason: 'Opacity badge text must be #FFFFFF in Dark Mode');

      // 3. Switch to Sliders tab
      await tester.tap(find.text("Sliders"));
      await tester.pumpAndSettle();

      // R, G, B labels are #FFFFFF
      final rLabel = tester.widget<Text>(find.text("R"));
      final gLabel = tester.widget<Text>(find.text("G"));
      final bLabel = tester.widget<Text>(find.text("B"));
      expect(rLabel.style?.color, const Color(0xFFFFFFFF),
          reason: 'R label must be #FFFFFF in Dark Mode');
      expect(gLabel.style?.color, const Color(0xFFFFFFFF),
          reason: 'G label must be #FFFFFF in Dark Mode');
      expect(bLabel.style?.color, const Color(0xFFFFFFFF),
          reason: 'B label must be #FFFFFF in Dark Mode');

      // SliderTheme inactive track is #3A3A3C
      final sliderThemes =
          tester.widgetList<SliderTheme>(find.byType(SliderTheme));
      for (final st in sliderThemes) {
        expect(st.data.inactiveTrackColor, const Color(0xFF3A3A3C),
            reason: 'Slider inactive track must be #3A3A3C in Dark Mode');
      }
    });

    testWidgets('Test 6 — Light Mode Opacity & RGB Regression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. "OPACITY" label is #8E8E93
      final opacityLabel = tester.widget<Text>(find.text("OPACITY"));
      expect(opacityLabel.style?.color, const Color(0xFF8E8E93),
          reason: '"OPACITY" label must be #8E8E93 in Light Mode');

      // 2. Opacity value box is Colors.white bg, #EFEFF4 border, #1C1C1E text
      final opacityBadgeContainer = tester.widget<Container>(find
          .ancestor(of: find.text("100%"), matching: find.byType(Container))
          .first);
      final badgeDec = opacityBadgeContainer.decoration as BoxDecoration;
      expect(badgeDec.color, Colors.white,
          reason: 'Opacity badge background must be Colors.white in Light Mode');
      expect(badgeDec.border?.top.color, const Color(0xFFEFEFF4),
          reason: 'Opacity badge border must be #EFEFF4 in Light Mode');
      final opacityText = tester.widget<Text>(find.text("100%"));
      expect(opacityText.style?.color, const Color(0xFF1C1C1E),
          reason: 'Opacity badge text must be #1C1C1E in Light Mode');

      // 3. Switch to Sliders tab
      await tester.tap(find.text("Sliders"));
      await tester.pumpAndSettle();

      // R, G, B labels are #1C1C1E
      final rLabel = tester.widget<Text>(find.text("R"));
      final gLabel = tester.widget<Text>(find.text("G"));
      final bLabel = tester.widget<Text>(find.text("B"));
      expect(rLabel.style?.color, const Color(0xFF1C1C1E),
          reason: 'R label must be #1C1C1E in Light Mode');
      expect(gLabel.style?.color, const Color(0xFF1C1C1E),
          reason: 'G label must be #1C1C1E in Light Mode');
      expect(bLabel.style?.color, const Color(0xFF1C1C1E),
          reason: 'B label must be #1C1C1E in Light Mode');

      // SliderTheme inactive track is #E5E5EA
      final sliderThemes =
          tester.widgetList<SliderTheme>(find.byType(SliderTheme));
      for (final st in sliderThemes) {
        expect(st.data.inactiveTrackColor, const Color(0xFFE5E5EA),
            reason: 'Slider inactive track must be #E5E5EA in Light Mode');
      }
    });

    testWidgets('Test 7 — Content Invariance', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildColorPickerHarness(isDark: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. GridView renders 120 swatches
      expect(find.byType(GridView), findsOneWidget);

      // 2. CheckerboardPainter is present in opacity track
      final checkerCustomPaint = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CheckerboardPainter);
      expect(checkerCustomPaint, findsOneWidget,
          reason: 'CheckerboardPainter must be present in opacity track');

      // 3. Switch to Spectrum tab -> SpectrumPainter is present
      await tester.tap(find.text("Spectrum"));
      await tester.pumpAndSettle();

      final spectrumCustomPaint = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SpectrumPainter);
      expect(spectrumCustomPaint, findsOneWidget,
          reason: 'SpectrumPainter must be present in spectrum tab');

      // 4. Switch to Sliders tab -> Active channels are Red, Green, Blue
      await tester.tap(find.text("Sliders"));
      await tester.pumpAndSettle();

      final sliders =
          tester.widgetList<SliderTheme>(find.byType(SliderTheme)).toList();
      expect(sliders[0].data.activeTrackColor, Colors.red,
          reason: 'R channel active color must remain Colors.red');
      expect(sliders[1].data.activeTrackColor, Colors.green,
          reason: 'G channel active color must remain Colors.green');
      expect(sliders[2].data.activeTrackColor, Colors.blue,
          reason: 'B channel active color must remain Colors.blue');
    });

    testWidgets('Test 8 — Presets & CTA Interaction', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Color? selectedColor;
      await tester.pumpWidget(buildColorPickerHarness(
        isDark: true,
        initialColor: const Color(0xFFFFCC00),
        onColorSelected: (c) => selectedColor = c,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Color Picker'));
      await tester.pumpAndSettle();

      // 1. Add preset button background is #3A3A3C, plus icon is #FFFFFF
      final addIcon = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
      expect(addIcon.color, const Color(0xFFFFFFFF),
          reason: 'Add preset icon must be #FFFFFF in Dark Mode');
      final addContainer = tester.widget<Container>(find
          .ancestor(
              of: find.byIcon(Icons.add_rounded),
              matching: find.byType(Container))
          .first);
      final addDec = addContainer.decoration as BoxDecoration;
      expect(addDec.color, const Color(0xFF3A3A3C),
          reason: 'Add preset button bg must be #3A3A3C in Dark Mode');

      // 2. Divider is #3A3A3C
      final divider = tester.widget<Divider>(find.byType(Divider).first);
      expect(divider.color, const Color(0xFF3A3A3C),
          reason: 'Divider must be #3A3A3C in Dark Mode');

      // 3. CTA text "Select Color" is #FFFFFF
      final ctaText = tester.widget<Text>(find.text("Select Color"));
      expect(ctaText.style?.color, const Color(0xFFFFFFFF),
          reason: 'CTA text must be #FFFFFF in Dark Mode');

      // 4. Tap CTA -> onColorSelected called, dialog dismissed
      await tester.tap(find.text("Select Color"));
      await tester.pumpAndSettle();

      expect(selectedColor, isNotNull);
      expect(selectedColor!.toARGB32(), equals(const Color(0xFFFFCC00).toARGB32()),
          reason: 'Selected color must match initial selected color');
      expect(find.byType(IosColorPickerDialog), findsNothing,
          reason: 'Dialog must be dismissed after CTA tap');
    });
  });
}



