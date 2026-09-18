import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/views/screens/note_editor_screen.dart';
import 'package:quick_notes/views/widgets/paper_guide_painters.dart';

Note _createTestNote({
  required String id,
  String title = 'Test Note',
  String content = 'Testing paper guides',
  bool paperGuideVisible = false,
  String paperGuideType = 'lines_extra_tight',
  double paperGuideHeight = 1.05,
  double paperGuideOpacity = 0.15,
  int paperGuideColor = 0,
}) {
  return Note(
    id: id,
    title: title,
    content: content,
    paperGuideVisible: paperGuideVisible,
    paperGuideType: paperGuideType,
    paperGuideHeight: paperGuideHeight,
    paperGuideOpacity: paperGuideOpacity,
    paperGuideColor: paperGuideColor,
    createdAt: DateTime(2026, 1, 1, 10, 0),
    updatedAt: DateTime(2026, 1, 1, 12, 0),
    colorValue: 0xFFFFFF,
    tags: const [],
    attachments: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget buildEditorScreen({required ThemeData theme, Note? note}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PremiumEntitlementManager()),
        ProxyProvider<PremiumEntitlementManager, FeatureAccess>(
          update: (_, manager, __) => DefaultFeatureAccess(manager),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: MaterialApp(
        theme: theme,
        home: NoteEditorScreen(note: note),
      ),
    );
  }

  group('D6-D3 Paper Guides & Paper Settings Dark Mode Contract Tests', () {
    test('GlobalPaperGuidePainter color, opacity, and shouldRepaint contract',
        () {
      final lightPainter = GlobalPaperGuidePainter(
        guideType: 'grid',
        spacing: 20.0,
        color: const Color(0xFF333333),
        opacity: 0.15,
      );
      expect(lightPainter.color, const Color(0xFF333333));
      expect(lightPainter.opacity, 0.15);

      final darkPainter = GlobalPaperGuidePainter(
        guideType: 'grid',
        spacing: 20.0,
        color: Colors.white,
        opacity: 0.15,
      );
      expect(darkPainter.color, Colors.white);
      expect(darkPainter.opacity, 0.15);

      // Custom color preserved in painter
      const customColor = Color(0xFFFFCC00);
      final customPainter = GlobalPaperGuidePainter(
        guideType: 'dots',
        spacing: 20.0,
        color: customColor,
        opacity: 0.25,
      );
      expect(customPainter.color, customColor);
      expect(customPainter.opacity, 0.25);

      // shouldRepaint triggers on color change
      expect(darkPainter.shouldRepaint(lightPainter), isTrue);
      // shouldRepaint triggers on opacity change
      final diffOpacityPainter = GlobalPaperGuidePainter(
        guideType: 'grid',
        spacing: 20.0,
        color: Colors.white,
        opacity: 0.30,
      );
      expect(diffOpacityPainter.shouldRepaint(darkPainter), isTrue);
      // shouldRepaint false for identical properties
      final identicalPainter = GlobalPaperGuidePainter(
        guideType: 'grid',
        spacing: 20.0,
        color: Colors.white,
        opacity: 0.15,
      );
      expect(identicalPainter.shouldRepaint(darkPainter), isFalse);
    });

    test('BlockPaperGuidePainter color, opacity, and shouldRepaint contract',
        () {
      final lightPainter = BlockPaperGuidePainter(
        guideType: 'lines_tight',
        lineHeight: 20.0,
        color: const Color(0xFF333333),
        opacity: 0.15,
      );
      expect(lightPainter.color, const Color(0xFF333333));

      final darkPainter = BlockPaperGuidePainter(
        guideType: 'lines_tight',
        lineHeight: 20.0,
        color: Colors.white,
        opacity: 0.15,
      );
      expect(darkPainter.color, Colors.white);

      const customColor = Color(0xFF4EA8DE);
      final customPainter = BlockPaperGuidePainter(
        guideType: 'lines_tight',
        lineHeight: 20.0,
        color: customColor,
        opacity: 0.15,
      );
      expect(customPainter.color, customColor);
      expect(darkPainter.shouldRepaint(lightPainter), isTrue);
    });

    testWidgets(
        'Paper guide color resolution: Default color in Light Mode -> #333333',
        (WidgetTester tester) async {
      final note = _createTestNote(
        id: 'light_guide_note',
        title: 'Light Guide Note',
        paperGuideVisible: true,
        paperGuideType: 'grid',
        paperGuideColor: 0, // Default
        paperGuideOpacity: 0.15,
      );

      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData.light(),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final customPaintFinder = find.byWidgetPredicate((w) {
        return w is CustomPaint && w.painter is GlobalPaperGuidePainter;
      });
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as GlobalPaperGuidePainter;
      expect(painter.color, const Color(0xFF333333));
      expect(painter.opacity, 0.15);
    });

    testWidgets(
        'Paper guide color resolution: Default color in Dark Mode -> #FFFFFF',
        (WidgetTester tester) async {
      final note = _createTestNote(
        id: 'dark_guide_note',
        title: 'Dark Guide Note',
        paperGuideVisible: true,
        paperGuideType: 'grid',
        paperGuideColor: 0, // Default
        paperGuideOpacity: 0.15,
      );

      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData(brightness: Brightness.dark),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final customPaintFinder = find.byWidgetPredicate((w) {
        return w is CustomPaint && w.painter is GlobalPaperGuidePainter;
      });
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as GlobalPaperGuidePainter;
      expect(painter.color, Colors.white);
      expect(painter.opacity, 0.15);
    });

    testWidgets(
        'Paper guide color resolution: Explicit custom color preserved in Light & Dark Mode',
        (WidgetTester tester) async {
      const explicitColor = 0xFFFFCC00; // Amber/Yellow
      final note = _createTestNote(
        id: 'custom_color_note',
        title: 'Custom Color Guide Note',
        paperGuideVisible: true,
        paperGuideType: 'grid',
        paperGuideColor: explicitColor,
        paperGuideOpacity: 0.20,
      );

      // 1. Light Mode
      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData.light(),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      var customPaint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) {
        return w is CustomPaint && w.painter is GlobalPaperGuidePainter;
      }));
      var painter = customPaint.painter as GlobalPaperGuidePainter;
      expect(painter.color, const Color(explicitColor));
      expect(painter.opacity, 0.20);

      // 2. Dark Mode
      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData(brightness: Brightness.dark),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      customPaint = tester.widget<CustomPaint>(find.byWidgetPredicate((w) {
        return w is CustomPaint && w.painter is GlobalPaperGuidePainter;
      }));
      painter = customPaint.painter as GlobalPaperGuidePainter;
      expect(painter.color, const Color(explicitColor));
      expect(painter.opacity, 0.20);
    });

    testWidgets('Paper Settings Bottom Sheet UI styling in Dark Mode',
        (WidgetTester tester) async {
      final note = _createTestNote(
        id: 'settings_dark_note',
        title: 'Settings Test Note',
        paperGuideVisible: true,
        paperGuideType: 'grid',
        paperGuideColor: 0,
        paperGuideOpacity: 0.15,
      );

      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData(brightness: Brightness.dark),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Swipe PageView to page 2 where Icons.grid_on_rounded resides
      final pageViewFinder = find.byType(PageView);
      if (pageViewFinder.evaluate().isNotEmpty) {
        await tester.drag(pageViewFinder.last, const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      final gridIconFinder = find.byIcon(Icons.grid_on_rounded);
      expect(gridIconFinder, findsWidgets);
      await tester.tap(gridIconFinder.first);
      await tester.pumpAndSettle();

      // 1. Sheet Surface: #2C2C2C
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(sheetContainerFinder, findsWidgets);

      // 2. Handle: #5A5A5A
      final handleFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(handleFinder, findsOneWidget);

      // 3. Primary Text: #FFFFFF
      final titleText = tester.widget<Text>(find.text('Paper & Spacing Setup'));
      expect(titleText.style?.color, Colors.white);

      // 4. Secondary Text: #8E8E93
      final switchText = tester.widget<Text>(find.text('Show Writing Guides'));
      expect(switchText.style?.color, const Color(0xFF8E8E93));

      // 5. Divider: Colors.white @ 15%
      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsWidgets);
      final divider = tester.widget<Divider>(dividerFinder.first);
      expect(divider.color, Colors.white.withValues(alpha: 0.15));

      // 6. Elevated Controls: #3A3A3C (for unselected guide cards)
      final elevatedControlFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == const Color(0xFF3A3A3C);
        }
        return false;
      });
      expect(elevatedControlFinder, findsWidgets);

      // 7. Sliders use primary activeColor and #3A3A3C inactiveColor
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsWidgets);
      final slider = tester.widget<Slider>(sliderFinder.first);
      expect(slider.inactiveColor, const Color(0xFF3A3A3C));
    });

    testWidgets('Paper Settings Bottom Sheet UI styling in Light Mode',
        (WidgetTester tester) async {
      final note = _createTestNote(
        id: 'settings_light_note',
        title: 'Light Settings Note',
        paperGuideVisible: true,
        paperGuideType: 'grid',
        paperGuideColor: 0,
        paperGuideOpacity: 0.15,
      );

      await tester.pumpWidget(buildEditorScreen(
        theme: ThemeData.light(),
        note: note,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final pageViewFinder = find.byType(PageView);
      if (pageViewFinder.evaluate().isNotEmpty) {
        await tester.drag(pageViewFinder.last, const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      final gridIconFinder = find.byIcon(Icons.grid_on_rounded);
      expect(gridIconFinder, findsWidgets);
      await tester.tap(gridIconFinder.first);
      await tester.pumpAndSettle();

      // Sheet Surface: Colors.white
      final sheetContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.color == Colors.white;
        }
        return false;
      });
      expect(sheetContainerFinder, findsWidgets);

      // Title Text: Colors.black87
      final titleText = tester.widget<Text>(find.text('Paper & Spacing Setup'));
      expect(titleText.style?.color, Colors.black87);

      // Secondary Text: Colors.black54
      final switchText = tester.widget<Text>(find.text('Show Writing Guides'));
      expect(switchText.style?.color, Colors.black54);
    });
  });
}
